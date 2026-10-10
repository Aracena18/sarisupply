import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeEach, afterAll, expect, it } from 'vitest';
import { manageDeliveries, getDriverWorkspaces } from '../../src/delivery/delivery-service';
const app = initializeApp({projectId:'demo-sarisupply-rules'}, 'audit-delivery');
const db = getFirestore(app), root = 'merchants/delivery-audit';
const driver = {auth:{uid:'driver-audit',token:{}}};
const owner = {auth:{uid:'owner-audit',token:{}}};
const item = {productId:'p',productName:'Rice',sku:'RICE',quantityOrdered:5,
  quantityDelivered:0,quantityReturned:0,unitCostCentavos:100,returnReason:null};
const proof = {id:'proof-audit',stopId:'stop',recipientName:'Rosa',recipientRole:'Owner',
  signatureSvg:'<svg/>',cashCollectedCentavos:300,driverNotes:'',deliveredAt:'2026-10-05T08:00:00Z',offlineCreated:true};
const command = (items = [{...item,quantityDelivered:3,quantityReturned:2,returnReason:'Damaged'}]) =>
  ({merchantId:'delivery-audit',action:'submitStopProof',runId:'run',stopId:'stop',proof,items});
beforeEach(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required');
  await db.recursiveDelete(db.doc(root));
  await db.doc(root).set({status:'active'});
  await db.doc(`${root}/drivers/driver-audit`).set({status:'active',warehouseId:'warehouse',driverName:'Driver'});
  await db.doc(`${root}/memberships/owner-audit`).set({status:'active',role:'owner',allBranches:true,branchIds:[],userId:'owner-audit',merchantId:'delivery-audit'});
  await db.doc('driverWorkspaces/driver-audit/assignments/delivery-audit').set({warehouseId:'forged-cache'});
  await db.doc(`${root}/warehouses/warehouse`).set({active:true});
  await db.doc(`${root}/warehouses/warehouse/stock/p`).set({physicalQuantity:10,reservedQuantity:0});
  await db.doc(`${root}/branches/branch`).set({merchantId:'delivery-audit',status:'active'});
  await db.doc(`${root}/packageManifests/package`).set({warehouseId:'warehouse',destinationId:'branch',items:[item],status:'assigned',runId:'run'});
  await db.doc(`${root}/delivery_runs/run`).set({id:'run',driverId:'driver-audit',warehouseId:'warehouse',status:'dispatched',
    createdAt:new Date().toISOString(),stops:[{id:'stop',destinationId:'branch',packageManifestId:'package',status:'pending',items:[item],proof:null}]});
});
afterAll(() => deleteApp(app));
it('valid partial delivery uses the manifest and settles exactly once', async () => {
  expect(await manageDeliveries(db,driver,command())).toMatchObject({status:'proofRecorded',runStatus:'completed'});
  expect(await manageDeliveries(db,driver,command())).toMatchObject({status:'duplicate'});
  const run = (await db.doc(`${root}/delivery_runs/run`).get()).data()!;
  expect(run.stops[0].items[0]).toMatchObject({quantityOrdered:5,quantityDelivered:3,quantityReturned:2,unitCostCentavos:100});
  expect((await db.collection(`${root}/deliveryOperations`).get()).size).toBe(1);
  expect((await db.doc(`${root}/branches/branch/stock/p`).get()).get('quantity')).toBe(3);
  expect((await db.doc(`${root}/branches/branch/inventoryMeta/stock`).get()).get('sequence')).toBe(1);
  expect((await db.doc(`${root}/deliveryCollections/proof-audit`).get()).data()).toMatchObject({amountCentavos:300,outstandingCentavos:0});
  expect((await db.doc(`${root}/deliveryReturns/proof-audit`).get()).get('status')).toBe('awaitingReceipt');
  expect((await db.doc(`${root}/warehouses/warehouse/stock/p`).get()).get('physicalQuantity')).toBe(10);
  const receipt = {merchantId:'delivery-audit',action:'receiveReturns',returnId:'proof-audit',operationId:'return-receipt',disposition:'restock'};
  await expect(manageDeliveries(db,driver,receipt)).rejects.toMatchObject({code:'permission-denied'});
  expect(await manageDeliveries(db,owner,receipt)).toMatchObject({status:'received'});
  expect(await manageDeliveries(db,owner,receipt)).toMatchObject({status:'duplicate'});
  expect((await db.doc(`${root}/warehouses/warehouse/stock/p`).get()).get('physicalQuantity')).toBe(12);

});
it('rejects excess quantities, inflated collection, and changed replay', async () => {
  await expect(manageDeliveries(db,driver,command([{...item,quantityDelivered:6,quantityReturned:0,returnReason:'Damaged'}]))).rejects.toMatchObject({code:'invalid-argument'});
  await expect(manageDeliveries(db,driver,{...command(),proof:{...proof,cashCollectedCentavos:301}})).rejects.toMatchObject({code:'invalid-argument'});
  await manageDeliveries(db,driver,command());
  await expect(manageDeliveries(db,driver,{...command(),proof:{...proof,recipientName:'Changed'}})).rejects.toMatchObject({code:'already-exists'});
});
it('revocation denies reconnect and removes workspace; Owner cannot impersonate a Driver', async () => {
  expect(await getDriverWorkspaces(db,driver)).toMatchObject({workspaces:[{warehouseId:'warehouse'}]});
  await expect(manageDeliveries(db,owner,command())).rejects.toMatchObject({code:'permission-denied'});
  await db.doc(`${root}/drivers/driver-audit`).update({status:'removed'});
  await expect(manageDeliveries(db,driver,command())).rejects.toMatchObject({code:'permission-denied'});
  expect(await getDriverWorkspaces(db,driver)).toEqual({workspaces:[]});
});

it('quarantined returns cannot increase sellable warehouse stock', async () => {
  await manageDeliveries(db,driver,command());
  const receipt = {merchantId:'delivery-audit',action:'receiveReturns',returnId:'proof-audit',operationId:'quarantine',disposition:'quarantine'};
  await manageDeliveries(db,owner,receipt);
  expect((await db.doc(`${root}/warehouseQuarantine/proof-audit`).get()).exists).toBe(true);
  expect((await db.doc(`${root}/warehouses/warehouse/stock/p`).get()).get('physicalQuantity')).toBe(10);
  await expect(manageDeliveries(db,owner,{...receipt,disposition:'restock'})).rejects.toMatchObject({code:'already-exists'});
});

it('warehouse reassignment denies old-run proof and status without changing stock', async () => {
  await db.doc(`${root}/drivers/driver-audit`).update({warehouseId:'other'});
  await expect(manageDeliveries(db,driver,command())).rejects.toMatchObject({code:'permission-denied'});
  await expect(manageDeliveries(db,driver,{merchantId:'delivery-audit',action:'updateStopStatus',runId:'run',stopId:'stop',operationId:'arrived',status:'arrived'})).rejects.toMatchObject({code:'permission-denied'});
  expect((await db.collection(`${root}/deliveryOperations`).get()).empty).toBe(true);
  expect((await db.doc(`${root}/branches/branch/stock/p`).get()).exists).toBe(false);
  expect((await db.doc(`${root}/delivery_runs/run`).get()).get('stops')[0].status).toBe('pending');
});

const locationCommand = (eventAtMs = Date.now(), overrides = {}) => ({
  merchantId:'delivery-audit', action:'updateDriverLocation', runId:'run',
  latitude:7.1, longitude:125.6, accuracyMeters:15,
  capturedAt:new Date().toISOString(), eventAtMs, ...overrides,
});
it('GPS is owner-readable and overwrites only latest snapshot', async () => {
  const now = Date.now();
  expect(await manageDeliveries(db,driver,locationCommand(now))).toMatchObject({location:{driverId:'driver-audit',sharing:true}});
  await manageDeliveries(db,driver,locationCommand(now+1,{latitude:7.2}));
  expect(await manageDeliveries(db,owner,{merchantId:'delivery-audit',action:'readDriverLocation',runId:'run'}))
    .toMatchObject({runId:'run',location:{latitude:7.2,driverId:'driver-audit'}});
  expect((await db.collection(`${root}/driverLocations`).get()).size).toBe(1);
  expect((await db.collection(`${root}/deliveryOperations`).get()).empty).toBe(true);
});
it('pause fences delayed GPS and duplicate pause preserves receipt time', async () => {
  const now = Date.now(); await manageDeliveries(db,driver,locationCommand(now));
  const before = (await db.doc(`${root}/driverLocations/run`).get()).get('receivedAt');
  const pause = {merchantId:'delivery-audit',action:'pauseDriverLocation',runId:'run',eventAtMs:now+2};
  await manageDeliveries(db,driver,pause); await manageDeliveries(db,driver,pause);
  await expect(manageDeliveries(db,driver,locationCommand(now+1))).rejects.toMatchObject({code:'failed-precondition'});
  expect((await db.doc(`${root}/driverLocations/run`).get()).data()).toMatchObject({sharing:false,receivedAt:before});
});
it('location denies impersonation, driver reads, other runs and businesses', async () => {
  await expect(manageDeliveries(db,owner,locationCommand())).rejects.toMatchObject({code:'permission-denied'});
  await expect(manageDeliveries(db,driver,{merchantId:'delivery-audit',action:'readDriverLocation',runId:'run'})).rejects.toMatchObject({code:'permission-denied'});
  await db.doc(`${root}/delivery_runs/other`).set({driverId:'someone-else',warehouseId:'warehouse',status:'dispatched'});
  await db.doc(`${root}/drivers/someone-else`).set({status:'active',warehouseId:'warehouse'});
  await expect(manageDeliveries(db,driver,locationCommand(Date.now(),{runId:'other'}))).rejects.toMatchObject({code:'permission-denied'});
  await db.doc('merchants/location-other-business').set({status:'active'});
  await expect(manageDeliveries(db,driver,locationCommand(Date.now(),{merchantId:'location-other-business'}))).rejects.toMatchObject({code:'permission-denied'});
  expect((await db.collection(`${root}/driverLocations`).get()).empty).toBe(true);
});
it('location rejects invalid coordinates, stale GPS and completed runs', async () => {
  for (const overrides of [{latitude:91},{longitude:181},{accuracyMeters:-1},
    {capturedAt:new Date(Date.now()-180000).toISOString()}]) {
    await expect(manageDeliveries(db,driver,locationCommand(Date.now(),overrides))).rejects.toMatchObject({code:'invalid-argument'});
  }
  await db.doc(`${root}/delivery_runs/run`).update({status:'completed'});
  await expect(manageDeliveries(db,driver,locationCommand())).rejects.toMatchObject({code:'failed-precondition'});
});
it('revoked or reassigned drivers cannot share or expose prior location', async () => {
  await manageDeliveries(db,driver,locationCommand());
  await db.doc(`${root}/drivers/driver-audit`).update({warehouseId:'other'});
  await expect(manageDeliveries(db,driver,locationCommand())).rejects.toMatchObject({code:'permission-denied'});
  await expect(manageDeliveries(db,owner,{merchantId:'delivery-audit',action:'readDriverLocation',runId:'run'})).rejects.toMatchObject({code:'permission-denied'});
  await db.doc(`${root}/drivers/driver-audit`).update({status:'removed'});
  await expect(manageDeliveries(db,driver,locationCommand())).rejects.toMatchObject({code:'permission-denied'});
});
