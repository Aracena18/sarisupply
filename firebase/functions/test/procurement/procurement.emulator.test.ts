import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeEach, afterAll, expect, it } from 'vitest';
import { managePurchaseOrders, manageRestockProposals } from '../../src/procurement/procurement-service';
import { manageDeliveries } from '../../src/delivery/delivery-service';
const app = initializeApp({projectId:'demo-sarisupply-rules'}, 'audit-purchasing');
const db = getFirestore(app), merchantId = 'purchasing-audit', root = `merchants/${merchantId}`;
const owner = {auth:{uid:'purchasing-owner',token:{}}};
const manager = {auth:{uid:'purchasing-manager',token:{}}};
const lines = ['p1','p2'].map(productId => ({productId,productName:productId,sku:productId,quantity:10,unitCostCentavos:100}));
const po = {id:'po',supplierId:'supplier',supplierName:'Supplier',warehouseId:'wh',notes:'',lines};
const proposals = lines.map(l => ({productId:l.productId,productName:l.productName,sku:l.sku,currentStock:-2,suggestedQuantity:4,approvedQuantity:0,pickedQuantity:0}));
beforeEach(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required');
  await db.recursiveDelete(db.doc(root));
  await db.doc(root).set({status:'active'});
  for (const [uid,role] of [['purchasing-owner','owner'],['purchasing-manager','manager']]) {
    await db.doc(`${root}/memberships/${uid}`).set({userId:uid,merchantId,role,status:'active',allBranches:true,branchIds:[]});
  }
  await db.doc(`${root}/branches/b`).set({status:'active',merchantId});
  await db.doc(`${root}/warehouses/wh`).set({active:true,name:'Warehouse'});
  await db.doc(`${root}/suppliers/supplier`).set({active:true,name:'Supplier'});
  for (const productId of ['p1','p2']) await db.doc(`${root}/products/${productId}`).set({active:true,name:productId,sku:productId});
  for (const productId of ['p1','p2']) await db.doc(`${root}/warehouses/wh/stock/${productId}`).set({physicalQuantity:10,reservedQuantity:0});
});
afterAll(() => deleteApp(app));
it('purchase creation and receiving replay without resetting or doubling stock', async () => {
  const create = {merchantId,action:'create',po};
  expect(await managePurchaseOrders(db,owner,create)).toMatchObject({status:'created'});
  const receive = {merchantId,action:'receive',poId:'po',productId:'p1',quantityReceived:5,operationId:'receive',batchNumber:'LOT-1',expiryDate:'2027-01-01'};
  await managePurchaseOrders(db,owner,receive);
  expect(await managePurchaseOrders(db,owner,receive)).toMatchObject({status:'duplicate'});
  expect(await managePurchaseOrders(db,owner,create)).toMatchObject({status:'duplicate'});
  expect((await db.doc(`${root}/warehouses/wh/batches/receive`).get()).data()).toMatchObject({quantity:5,expiryDate:'2027-01-01',unitCostCentavos:100});
  await expect(managePurchaseOrders(db,owner,{...receive,expiryDate:'2027-02-01'})).rejects.toMatchObject({code:'already-exists'});

  expect((await db.doc(`${root}/warehouses/wh/stock/p1`).get()).get('physicalQuantity')).toBe(15);
  expect((await db.doc(`${root}/purchaseOrders/po`).get()).get('lines')[0].quantityReceived).toBe(5);
  await expect(managePurchaseOrders(db,owner,{...receive,operationId:'excess',quantityReceived:6})).rejects.toMatchObject({code:'failed-precondition'});
  await expect(managePurchaseOrders(db,manager,create)).rejects.toMatchObject({code:'permission-denied'});
});
it('two-product approval and partial pack release reservations exactly once', async () => {
  const submit = {merchantId,action:'submit',proposal:{id:'proposal',branchId:'b',warehouseId:'wh',notes:'',lines:proposals}};
  await manageRestockProposals(db,owner,submit);
  const review = {merchantId,action:'review',proposalId:'proposal',approved:true};
  await manageRestockProposals(db,owner,review);
  await manageRestockProposals(db,owner,review);
  expect((await db.doc(`${root}/warehouses/wh/stock/p1`).get()).get('reservedQuantity')).toBe(4);
  const pick = {merchantId,action:'fulfill',proposalId:'proposal',stage:'pick',pickedLines:proposals.map((l,i) => ({...l,pickedQuantity:i===0?2:0}))};
  await manageRestockProposals(db,owner,pick);
  await manageRestockProposals(db,owner,pick);
  const pack = {merchantId,action:'fulfill',proposalId:'proposal',stage:'pack',packageCode:'package',sealNotes:''};
  await manageRestockProposals(db,owner,pack);
  await manageRestockProposals(db,owner,pack);
  expect((await db.doc(`${root}/warehouses/wh/stock/p1`).get()).data()).toMatchObject({physicalQuantity:8,reservedQuantity:0});
  expect((await db.doc(`${root}/warehouses/wh/stock/p2`).get()).data()).toMatchObject({physicalQuantity:10,reservedQuantity:0});
});
it('approval cannot reserve unavailable stock or change a reviewed decision', async () => {
  await manageRestockProposals(db,owner,{merchantId,action:'submit',proposal:{id:'proposal',branchId:'b',warehouseId:'wh',notes:'',lines:proposals}});
  const review = {merchantId,action:'review',proposalId:'proposal',approved:true};
  await expect(manageRestockProposals(db,owner,{...review,adjustedLines:proposals.map(l => ({...l,approvedQuantity:11}))})).rejects.toMatchObject({code:'failed-precondition'});
  expect((await db.doc(`${root}/warehouses/wh/stock/p1`).get()).get('reservedQuantity')).toBe(0);
  await manageRestockProposals(db,owner,review);
  await expect(manageRestockProposals(db,owner,{...review,approved:false})).rejects.toMatchObject({code:'failed-precondition'});
});

it('purchase receiving, packing, dispatch and delivery reconcile real shared records', async () => {
  await db.doc(`${root}/branches/b`).update({name:'Branch',address:'Main street'});
  await managePurchaseOrders(db,owner,{merchantId,action:'create',po});
  await managePurchaseOrders(db,owner,{merchantId,action:'receive',poId:'po',productId:'p1',quantityReceived:5,operationId:'purchase-stock'});
  await manageRestockProposals(db,owner,{merchantId,action:'submit',proposal:{id:'shipment',branchId:'b',warehouseId:'wh',notes:'',lines:[proposals[0]]}});
  await manageRestockProposals(db,owner,{merchantId,action:'review',proposalId:'shipment',approved:true});
  await manageRestockProposals(db,owner,{merchantId,action:'fulfill',proposalId:'shipment',stage:'pick',pickedLines:[{...proposals[0],pickedQuantity:4}]});
  await manageRestockProposals(db,owner,{merchantId,action:'fulfill',proposalId:'shipment',stage:'pack',packageCode:'BOX',sealNotes:''});
  await manageDeliveries(db,owner,{merchantId,action:'assignDriver',driverId:'purchasing-driver',driverName:'Driver',warehouseId:'wh'});
  const manifest = (await db.doc(`${root}/packageManifests/manifest-shipment`).get()).data()!;
  expect(manifest.items[0]).toMatchObject({quantityOrdered:4,unitCostCentavos:100});
  const run = {id:'shipment-run',driverId:'purchasing-driver',driverName:'Driver',warehouseId:'wh',vehicleInfo:'Vehicle 1',
    stops:[{id:'stop',sequence:1,destinationId:'b',destinationName:'Branch',destinationAddress:'Main street',packageManifestId:'manifest-shipment',items:manifest.items}]};
  await expect(manageDeliveries(db,owner,{merchantId,action:'createRun',run:{...run,stops:[{...run.stops[0],items:[{...manifest.items[0],quantityOrdered:5}]}]}})).rejects.toMatchObject({code:'failed-precondition'});
  expect(await manageDeliveries(db,owner,{merchantId,action:'createRun',run})).toMatchObject({status:'created'});
  expect(await manageDeliveries(db,owner,{merchantId,action:'createRun',run})).toMatchObject({status:'duplicate'});
  await expect(manageDeliveries(db,owner,{merchantId,action:'createRun',run:{...run,id:'other-run'}})).rejects.toMatchObject({code:'failed-precondition'});
  await manageDeliveries(db,owner,{merchantId,action:'dispatchRun',runId:run.id});
  const delivery = {merchantId,action:'submitStopProof',runId:run.id,stopId:'stop',
    proof:{id:'shipment-proof',stopId:'stop',recipientName:'Rosa',recipientRole:'Owner',signatureSvg:'<svg/>',deliveredAt:new Date().toISOString(),cashCollectedCentavos:250},
    items:[{...manifest.items[0],quantityDelivered:3,quantityReturned:1,returnReason:'Damaged'}]};
  const driver = {auth:{uid:'purchasing-driver',token:{}}};
  await manageDeliveries(db,driver,delivery);
  await manageDeliveries(db,driver,delivery);
  expect((await db.doc(`${root}/branches/b/stock/p1`).get()).get('quantity')).toBe(3);
  expect((await db.doc(`${root}/warehouses/wh/stock/p1`).get()).get('physicalQuantity')).toBe(11);
  expect((await db.doc(`${root}/deliveryCollections/shipment-proof`).get()).data()).toMatchObject({amountCentavos:250,outstandingCentavos:50});
  await manageDeliveries(db,owner,{merchantId,action:'receiveReturns',returnId:'shipment-proof',operationId:'received-return',disposition:'quarantine'});
  expect((await db.doc(`${root}/warehouses/wh/stock/p1`).get()).get('physicalQuantity')).toBe(11);
});
