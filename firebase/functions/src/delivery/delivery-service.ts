import { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { canonical } from '../checkout/checkout-validation';
import { createHash } from 'node:crypto';
import { requireDocumentId } from '../common/ids';

type Input = Record<string, unknown>;

function text(value: unknown, max: number, allowEmpty = false): string {
  if (typeof value !== 'string' || (!allowEmpty && !value.trim()) || value.length > max) {
    throw new HttpsError('invalid-argument', 'Invalid text');
  }
  return value.trim();
}

function integer(value: unknown, min = 0, max = 1000000000): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new HttpsError('invalid-argument', 'Invalid integer');
  }
  return value;
}

function authz(db: Firestore, tx: Transaction) {
  return new AuthorizationService(async (path) => (await tx.get(db.doc(path))).data() ?? null);
}

export async function manageDeliveries(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const action = text(input.action, 32);

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    const uid = requireHuman(request);
    const merchant = await tx.get(db.doc(`merchants/${merchantId}`));
    if (merchant.get('status') !== 'active') throw new HttpsError('permission-denied', 'Access denied');
    const driver = await tx.get(db.doc(`merchants/${merchantId}/drivers/${uid}`));
    const driverAction = ['listRuns', 'submitStopProof', 'updateStopStatus', 'updateDriverLocation', 'pauseDriverLocation'].includes(action);
    if (['submitStopProof','updateStopStatus','updateDriverLocation','pauseDriverLocation'].includes(action) && driver.get('status') !== 'active') throw new HttpsError('permission-denied','Active driver assignment required');
    if (!driverAction || driver.get('status') !== 'active') {
      await authorization.requireOwner(uid, merchantId);
    }

    if (['updateDriverLocation', 'pauseDriverLocation', 'readDriverLocation'].includes(action)) {
      const runId = requireDocumentId(input.runId, 'run ID');
      const root = `merchants/${merchantId}`;
      const run = await tx.get(db.doc(`${root}/delivery_runs/${runId}`));
      if (!run.exists) throw new HttpsError('not-found', 'Delivery run unavailable');
      const assignedDriverId = requireDocumentId(run.get('driverId'), 'driver ID');
      const warehouseId = requireDocumentId(run.get('warehouseId'), 'warehouse ID');
      const warehouse = await tx.get(db.doc(`${root}/warehouses/${warehouseId}`));
      if (warehouse.get('active') !== true) throw new HttpsError('permission-denied', 'Warehouse unavailable');
      const assigned = assignedDriverId === uid ? driver :
        await tx.get(db.doc(`${root}/drivers/${assignedDriverId}`));
      if (assigned.get('status') !== 'active' || assigned.get('warehouseId') !== warehouseId) {
        throw new HttpsError('permission-denied', 'Driver assignment changed');
      }
      const ref = db.doc(`${root}/driverLocations/${runId}`);
      const previous = await tx.get(ref);
      if (action === 'readDriverLocation') {
        // The normal owner authorization above applies even when the owner also drives.
        const raw = previous.data();
        return {runId, location: raw?.capturedAt && raw.driverId === assignedDriverId ?
          {...raw, sharing: raw.sharing === true && ['dispatched','inTransit'].includes(run.get('status'))} : null};
      }
      if (assignedDriverId !== uid) throw new HttpsError('permission-denied', 'Assigned driver required');
      const now = Date.now();
      const eventAtMs = integer(input.eventAtMs, 0, Number.MAX_SAFE_INTEGER);
      if (Math.abs(now - eventAtMs) > 300000) throw new HttpsError('invalid-argument', 'Check the phone date and time');
      const previousEvent = previous.get('eventAtMs');
      if (typeof previousEvent === 'number' && eventAtMs <= previousEvent) {
        if (action === 'pauseDriverLocation') return {status:'paused',runId};
        throw new HttpsError('failed-precondition', 'Location update is obsolete');
      }
      if (action === 'pauseDriverLocation') {
        tx.set(ref, {runId, driverId:uid, sharing:false, eventAtMs}, {merge:true});
        return {status:'paused',runId};
      }
      if (!['dispatched','inTransit'].includes(run.get('status'))) {
        throw new HttpsError('failed-precondition', 'Delivery run is no longer active');
      }
      const coordinate = (value: unknown, min: number, max: number) => {
        if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) {
          throw new HttpsError('invalid-argument', 'Invalid location');
        }
        return value;
      };
      const capturedAt = text(input.capturedAt, 40);
      const captureTime = Date.parse(capturedAt);
      if (!Number.isFinite(captureTime) || captureTime > now + 30000 || now - captureTime > 120000) {
        throw new HttpsError('invalid-argument', 'Location fix is too old');
      }
      const location = {runId, driverId:uid, warehouseId,
        latitude:coordinate(input.latitude,-90,90), longitude:coordinate(input.longitude,-180,180),
        accuracyMeters:coordinate(input.accuracyMeters,0,100000),
        capturedAt:new Date(captureTime).toISOString(), receivedAt:new Date(now).toISOString(),
        sharing:true, eventAtMs};
      tx.set(ref, location);
      return {runId, location};
    }

    if (action === 'assignDriver') {
      const driverId = requireDocumentId(input.driverId, 'driver ID');
      const driverName = text(input.driverName, 120);
      const warehouseId = requireDocumentId(input.warehouseId, 'warehouse ID');
      const status = input.active === false ? 'removed' : 'active';
      const warehouse = await tx.get(db.doc(`merchants/${merchantId}/warehouses/${warehouseId}`));
      if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
      tx.set(db.doc(`merchants/${merchantId}/drivers/${driverId}`), { userId: driverId, driverName, warehouseId, status });
      tx.set(db.doc(`driverWorkspaces/${driverId}/assignments/${merchantId}`), { merchantId, warehouseId, driverName, status });
      return { status };
    }

    if (action === 'readDispatchWorkspace') {
      const warehouseId = requireDocumentId(input.warehouseId,'warehouse ID');
      const root = `merchants/${merchantId}`;
      const warehouse = await tx.get(db.doc(`${root}/warehouses/${warehouseId}`));
      if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
      const [drivers,manifests,runs,returns] = await Promise.all([
        tx.get(db.collection(`${root}/drivers`).where('warehouseId','==',warehouseId).where('status','==','active').limit(51)),
        tx.get(db.collection(`${root}/packageManifests`).where('warehouseId','==',warehouseId).where('status','==','packed').limit(51)),
        tx.get(db.collection(`${root}/delivery_runs`).where('warehouseId','==',warehouseId).where('status','in',['draft','dispatched','inTransit']).limit(51)),
        tx.get(db.collection(`${root}/deliveryReturns`).where('warehouseId','==',warehouseId).where('status','==','awaitingReceipt').limit(51)),
      ]);
      const records = (page:FirebaseFirestore.QuerySnapshot) => page.docs.slice(0,50).map(d=>({...d.data(),id:d.id}));
      return {drivers:records(drivers),manifests:records(manifests),runs:records(runs),returns:records(returns),
        hasMore:[drivers,manifests,runs,returns].some(p=>p.size>50)};
    }
    if (action === 'receiveReturns') {
      const returnId = requireDocumentId(input.returnId,'return ID'), operationId = requireDocumentId(input.operationId,'operation ID');
      const disposition = text(input.disposition,20);
      if (!['restock','quarantine'].includes(disposition)) throw new HttpsError('invalid-argument','Select a return disposition');
      const ref = db.doc(`merchants/${merchantId}/deliveryReturns/${returnId}`), record = await tx.get(ref);
      if (!record.exists) throw new HttpsError('not-found','Return not found');
      if (record.get('status') === 'received') {
        if (record.get('receivedOperationId') !== operationId || record.get('disposition') !== disposition) throw new HttpsError('already-exists','Return receipt changed');
        return {status:'duplicate',returnId,operationId};
      }
      if (record.get('status') !== 'awaitingReceipt') throw new HttpsError('failed-precondition','Return cannot be received');
      const warehouseId = requireDocumentId(record.get('warehouseId'),'warehouse ID');
      const warehouse = await tx.get(db.doc(`merchants/${merchantId}/warehouses/${warehouseId}`));
      if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
      const writes: (()=>void)[] = [];
      if (disposition === 'restock') for (const item of record.get('items') as Input[]) {
        const productId = requireDocumentId(item.productId,'product ID');
        const stockRef = db.doc(`merchants/${merchantId}/warehouses/${warehouseId}/stock/${productId}`);
        const stock = await tx.get(stockRef);
        const physicalQuantity = integer(integer(stock.get('physicalQuantity')??0)+integer(item.quantity,1));
        writes.push(()=>tx.set(stockRef,{warehouseId,productId,physicalQuantity,reservedQuantity:integer(stock.get('reservedQuantity')??0)},{merge:true}));
      }
      for (const write of writes) write();
      if (disposition === 'quarantine') tx.create(db.doc(`merchants/${merchantId}/warehouseQuarantine/${returnId}`), {
        warehouseId,items:record.get('items'),operationId,receivedBy:uid,receivedAt:new Date().toISOString(),
      });
      tx.update(ref,{status:'received',receivedOperationId:operationId,disposition,receivedBy:uid,receivedAt:new Date().toISOString()});
      return {status:'received',returnId,operationId};
    }

    const root = `merchants/${merchantId}/delivery_runs`;

    if (action === 'createRun') {
      const runData = input.run as Record<string, unknown>;
      const runId = requireDocumentId(runData?.id, 'run ID');
      const driverId = requireDocumentId(runData.driverId, 'driver ID');
      const driverName = text(runData.driverName, 120);
      const vehicleInfo = text(runData.vehicleInfo, 100);
      const warehouseId = requireDocumentId(runData.warehouseId, 'warehouse ID');
      const notes = text(runData.notes ?? '', 500, true);
      const rawStops = (runData.stops as Array<Record<string, unknown>>) ?? [];

      const stops = rawStops.map((s, idx) => ({
        id: requireDocumentId(s.id, `stop ID at index ${idx}`),
        deliveryRunId: runId,
        sequence: integer(s.sequence ?? idx + 1, 1),
        destinationId: text(s.destinationId, 64),
        destinationName: text(s.destinationName, 120),
        destinationAddress: text(s.destinationAddress, 250),
        latitude: typeof s.latitude === 'number' ? s.latitude : null,
        longitude: typeof s.longitude === 'number' ? s.longitude : null,
        contactPerson: text(s.contactPerson ?? '', 100, true),
        contactPhone: text(s.contactPhone ?? '', 32, true),
        packageManifestId: requireDocumentId(s.packageManifestId,'package manifest ID'),
        status: 'pending',
        items: ((s.items as Array<Record<string, unknown>>) ?? []).map((i) => ({
          productId: text(i.productId, 64),
          productName: text(i.productName, 120),
          sku: text(i.sku, 64),
          quantityOrdered: integer(i.quantityOrdered, 1),
          quantityDelivered: 0,
          quantityReturned: 0,
          unitCostCentavos: integer(i.unitCostCentavos ?? 0, 0),
          returnReason: null,
        })),
        proof: null,
        failureReason: null,
        notes: text(s.notes ?? '', 500, true),
      }));

      if (!stops.length || stops.length > 20 || new Set(stops.map(s => s.id)).size !== stops.length) {
        throw new HttpsError('invalid-argument', 'Select unique delivery stops');
      }
      const assigned = await tx.get(db.doc(`merchants/${merchantId}/drivers/${driverId}`));
      if (assigned.get('status') !== 'active') throw new HttpsError('failed-precondition', 'Assign the driver first');
      const docRef = db.doc(`${root}/${runId}`);
      const existing = await tx.get(docRef);
      const fingerprint = createHash('sha256').update(canonical(runData)).digest('hex');
      if (existing.exists) {
        if (existing.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists', 'Run ID has another manifest');
        return {status: 'duplicate', runId};
      }
      if (assigned.get('warehouseId') !== warehouseId || assigned.get('driverName') !== driverName) {
        throw new HttpsError('failed-precondition','Driver assignment changed');
      }
      const warehouse = await tx.get(db.doc(`merchants/${merchantId}/warehouses/${warehouseId}`));
      if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
      if (new Set(stops.map(s => s.packageManifestId)).size !== stops.length) throw new HttpsError('invalid-argument','Select unique packages');
      const manifests = [];
      for (const stop of stops) {
        const ref = db.doc(`merchants/${merchantId}/packageManifests/${stop.packageManifestId}`);
        const manifest = await tx.get(ref);
        if (!manifest.exists || manifest.get('status') !== 'packed' || manifest.get('warehouseId') !== warehouseId ||
            manifest.get('destinationId') !== stop.destinationId || !stop.items.length || stop.items.length > 20) {
          throw new HttpsError('failed-precondition','Select an available packed manifest');
        }
        const packed = manifest.get('items') as Input[];
        if (packed.length !== stop.items.length || new Set(stop.items.map(i => i.productId)).size !== stop.items.length ||
            stop.items.some(i => !packed.some(p => p.productId === i.productId && p.sku === i.sku &&
              p.productName === i.productName && p.quantityOrdered === i.quantityOrdered &&
              typeof p.unitCostCentavos === 'number' && p.unitCostCentavos === i.unitCostCentavos))) {
          throw new HttpsError('failed-precondition','Delivery manifest changed or purchase cost is unavailable');
        }
        manifests.push(ref);
      }
      for (const ref of manifests) tx.update(ref,{status:'assigned',runId});
      tx.create(docRef, { fingerprint,
        id: runId,
        driverId,
        driverName,
        vehicleInfo,
        warehouseId,
        status: 'draft',
        stops,
        createdAt: new Date().toISOString(),
        startedAt: null,
        completedAt: null,
        notes,
      });

      return { status: 'created', runId };
    }

    if (action === 'dispatchRun') {
      const runId = requireDocumentId(input.runId, 'run ID');
      const docRef = db.doc(`${root}/${runId}`);
      const doc = await tx.get(docRef);
      if (!doc.exists) throw new HttpsError('not-found', 'Delivery run not found');

      if (doc.get('status') !== 'draft') {
        if (['dispatched', 'inTransit', 'completed'].includes(doc.get('status'))) return {status: 'dispatched', runId};
        throw new HttpsError('failed-precondition', 'Run cannot be dispatched');
      }
      const assigned = await tx.get(db.doc(`merchants/${merchantId}/drivers/${doc.get('driverId')}`));
      if (assigned.get('status') !== 'active' || assigned.get('warehouseId') !== doc.get('warehouseId')) {
        throw new HttpsError('failed-precondition','Driver assignment changed');
      }
      const now = new Date().toISOString();
      tx.update(docRef, {
        status: 'dispatched',
        startedAt: now,
      });

      return { status: 'dispatched', runId, startedAt: now };
    }

    if (action === 'submitStopProof') {
      const runId = requireDocumentId(input.runId, 'run ID');
      const stopId = requireDocumentId(input.stopId, 'stop ID');
      const proofData = input.proof as Record<string, unknown>;
      if (!proofData) throw new HttpsError('invalid-argument', 'Missing delivery proof');

      const recipientName = text(proofData.recipientName, 120);
      const recipientRole = text(proofData.recipientRole, 64);
      const signatureSvg = text(proofData.signatureSvg, 50000,true);
      const cashCollectedCentavos = integer(proofData.cashCollectedCentavos ?? 0, 0);
      const driverNotes = text(proofData.driverNotes ?? '', 500, true);
      const deliveredAt = text(proofData.deliveredAt ?? new Date().toISOString(), 64);

      const rawItems = (input.items as Array<Record<string, unknown>>) ?? [];

      const docRef = db.doc(`${root}/${runId}`);
      const doc = await tx.get(docRef);
      if (!doc.exists) throw new HttpsError('not-found', 'Delivery run not found');
      const run = doc.data()!;
      if (run.driverId !== uid || driver.get('warehouseId') !== run.warehouseId) throw new HttpsError('permission-denied', 'Current warehouse assignment required for delivery');
      const stops = (run.stops as Array<Record<string, unknown>>) ?? [];
      const stopIndex = stops.findIndex((s) => s.id === stopId);
      if (stopIndex === -1) throw new HttpsError('not-found', 'Stop not found in run');

      const existingStop = stops[stopIndex];
      const oldProof = existingStop.proof as Record<string, unknown> | null;
      const proofId = requireDocumentId(proofData.id, 'proof ID');
      const proofHash = createHash('sha256').update(canonical({proof: proofData, items: rawItems})).digest('hex');
      const proofRef = db.doc(`merchants/${merchantId}/deliveryOperations/${proofId}`);
      const previous = await tx.get(proofRef);
      if (previous.exists) {
        if (previous.get('fingerprint') !== proofHash || previous.get('runId') !== runId || previous.get('stopId') !== stopId) throw new HttpsError('already-exists', 'Proof ID has another delivery');
        return {status: 'duplicate', runId, stopId};
      }
      if (oldProof || !['dispatched','inTransit'].includes(run.status)) throw new HttpsError('failed-precondition', 'Delivery already settled or unavailable');
      const manifestItems = existingStop.items as Array<Record<string, unknown>>;
      if (!rawItems.length || rawItems.length !== manifestItems.length || new Set(rawItems.map(i => i.productId)).size !== rawItems.length) {
        throw new HttpsError('invalid-argument', 'Delivery items must match the manifest');
      }
      const updatedItems = rawItems.map((i) => {
        const manifest = manifestItems.find(m => m.productId === i.productId);
        if (!manifest) throw new HttpsError('invalid-argument', 'Unknown manifest item');
        const qOrdered = integer(manifest.quantityOrdered, 1);
        const qDelivered = integer(i.quantityDelivered, 0);
        const qReturned = integer(i.quantityReturned, 0);
        if (qDelivered + qReturned !== qOrdered) throw new HttpsError('invalid-argument', 'Account for every packed unit as delivered or returned');
        if (qReturned > 0 && !i.returnReason) throw new HttpsError('invalid-argument', 'Return reason required');
        const returnReason = i.returnReason ? text(i.returnReason, 200, true) : null;
        return {
          productId: text(i.productId, 64),
          productName: manifest.productName,
          sku: manifest.sku,
          quantityOrdered: qOrdered,
          quantityDelivered: qDelivered,
          quantityReturned: qReturned,
          unitCostCentavos: manifest.unitCostCentavos,
          returnReason,
        };
      });

      const totalDelivered = updatedItems.reduce((sum, item) => sum + item.quantityDelivered, 0);
      if (totalDelivered > 0 && !signatureSvg) throw new HttpsError('invalid-argument','Recipient signature required');
      const totalReturned = updatedItems.reduce((sum, item) => sum + item.quantityReturned, 0);

      const due = updatedItems.reduce((sum, item) => sum + item.quantityDelivered * integer(item.unitCostCentavos), 0);
      if (cashCollectedCentavos > due) throw new HttpsError('invalid-argument', 'Collection exceeds delivered value');
      let stopStatus = totalDelivered < manifestItems.reduce((n, i) => n + integer(i.quantityOrdered), 0) ? 'partiallyDelivered' : 'delivered';
      if (totalDelivered === 0 && totalReturned > 0) {
        stopStatus = 'failed';
      } else if (totalReturned > 0) {
        stopStatus = 'partiallyDelivered';
      }

      integer(due);
      const destinationId = requireDocumentId(existingStop.destinationId,'destination branch ID');
      const branchRoot = `merchants/${merchantId}/branches/${destinationId}`;
      const branch = await tx.get(db.doc(branchRoot));
      if (branch.get('status') !== 'active' || branch.get('merchantId') !== merchantId) throw new HttpsError('failed-precondition','Delivery destination is unavailable');
      const stockWrites: {productId:string;quantity:number;revision:number;delta:number}[] = [];
      for (const item of updatedItems.filter(i => i.quantityDelivered > 0)) {
        const current = await tx.get(db.doc(`${branchRoot}/stock/${item.productId}`));
        stockWrites.push({productId:item.productId,quantity:integer(integer(current.get('quantity')??0,-1000000000)+item.quantityDelivered,-1000000000),
          revision:integer(current.get('revision')??0)+1,delta:item.quantityDelivered});
      }
      const metaRef = db.doc(`${branchRoot}/inventoryMeta/stock`);
      const sequence = stockWrites.length ? integer((await tx.get(metaRef)).get('sequence')??0)+1 : null;
      const manifestRef = db.doc(`merchants/${merchantId}/packageManifests/${requireDocumentId(existingStop.packageManifestId,'manifest ID')}`);
      const manifest = await tx.get(manifestRef);
      if (manifest.get('runId') !== runId || manifest.get('status') !== 'assigned') {
        throw new HttpsError('failed-precondition','Packed shipment needs review');
      }

      const proof = {
        id: proofData.id ? text(proofData.id, 64) : `proof-${stopId}`,
        stopId,
        recipientName,
        recipientRole,
        signatureSvg,
        cashCollectedCentavos,
        driverNotes,
        deliveredAt,
        offlineCreated: false,
      };

      stops[stopIndex] = {
        ...existingStop,
        status: stopStatus,
        items: updatedItems,
        proof,
      };

      const allFinished = stops.every(
        (s) =>
          s.status === 'delivered' ||
          s.status === 'partiallyDelivered' ||
          s.status === 'failed' ||
          s.status === 'cancelled'
      );

      const runStatus = allFinished ? 'completed' : 'inTransit';
      const completedAt = allFinished ? new Date().toISOString() : (run.completedAt ?? null);

      for (const item of stockWrites) tx.set(db.doc(`${branchRoot}/stock/${item.productId}`),{quantity:item.quantity,revision:item.revision});
      if (sequence != null) {
        tx.set(metaRef,{sequence});
        tx.create(db.doc(`${branchRoot}/stockChanges/${String(sequence).padStart(10,'0')}`), {
          sequence,operationId:`delivery-${proofHash}`,kind:'receiving',positions:stockWrites,
        });
      }
      tx.update(manifestRef,{status:'settled',proofId});
      tx.create(db.doc(`merchants/${merchantId}/deliveryCollections/${proofId}`), {
        runId,stopId,driverId:uid,branchId:destinationId,amountCentavos:cashCollectedCentavos,
        deliveredValueCentavos:due,outstandingCentavos:due-cashCollectedCentavos,recordedAt:new Date().toISOString(),
      });
      const returns = updatedItems.filter(i => i.quantityReturned > 0);
      if (returns.length) tx.create(db.doc(`merchants/${merchantId}/deliveryReturns/${proofId}`), {
        runId,stopId,warehouseId:run.warehouseId,items:returns.map(i => ({productId:i.productId,quantity:i.quantityReturned,reason:i.returnReason})),
        status:'awaitingReceipt',recordedAt:new Date().toISOString(),
      });
      tx.create(proofRef, {fingerprint: proofHash, runId, stopId, proof, items: updatedItems, recordedAt: new Date().toISOString()});
      tx.update(docRef, {
        stops,
        status: runStatus,
        completedAt,
      });

      return {
        status: 'proofRecorded',
        runId,
        stopId,
        stopStatus,
        runStatus,
        completedAt,
      };
    }

    if (action === 'updateStopStatus') {
      const runId = requireDocumentId(input.runId, 'run ID');
      const stopId = requireDocumentId(input.stopId, 'stop ID');
      const operationId = requireDocumentId(input.operationId, 'operation ID');
      const status = text(input.status, 32);
      if (!['arrived','failed'].includes(status)) throw new HttpsError('invalid-argument', 'Invalid stop transition');
      const ref = db.doc(`${root}/${runId}`);
      const run = (await tx.get(ref)).data();
      if (!run || run.driverId !== uid || driver.get('warehouseId') !== run.warehouseId) throw new HttpsError('permission-denied', 'Current warehouse assignment required for delivery');
      const receipt = db.doc(`merchants/${merchantId}/deliveryOperations/${operationId}`);
      const hash = createHash('sha256').update(canonical(input)).digest('hex');
      const replay = await tx.get(receipt);
      if (replay.exists) {
        if (replay.get('fingerprint') !== hash) throw new HttpsError('already-exists', 'Operation changed');
        return {status: 'duplicate', operationId};
      }
      const stops = run.stops as Array<Record<string, unknown>>;
      const stop = stops.find(s => s.id === stopId);
      if (!stop || !['pending','arrived'].includes(stop.status as string) || !['dispatched','inTransit'].includes(run.status)) {
        throw new HttpsError('failed-precondition', 'Stop is unavailable');
      }
      let failedManifestRef:FirebaseFirestore.DocumentReference | null = null;
      if (status === 'failed') {
        const manifestId = requireDocumentId(stop.packageManifestId,'manifest ID');
        failedManifestRef = db.doc(`merchants/${merchantId}/packageManifests/${manifestId}`);
        const manifest = await tx.get(failedManifestRef);
        if (manifest.get('status') !== 'assigned' || manifest.get('runId') !== runId) throw new HttpsError('failed-precondition','Packed shipment needs review');
      }
      stop.status = status;
      if (status === 'failed') stop.failureReason = text(input.reason, 200);
      if (failedManifestRef) {
        tx.update(failedManifestRef,{status:'settled',failureOperationId:operationId});
        tx.create(db.doc(`merchants/${merchantId}/deliveryReturns/${operationId}`), {
          runId,stopId,warehouseId:run.warehouseId,status:'awaitingReceipt',
          items:(stop.items as Input[]).map(i=>({productId:i.productId,quantity:integer(i.quantityOrdered,1),reason:stop.failureReason})),
          recordedAt:new Date().toISOString(),
        });
      }
      const completed = stops.every(s => ['delivered','partiallyDelivered','failed','cancelled'].includes(s.status as string));
      tx.update(ref, {stops, status: completed ? 'completed' : 'inTransit', ...(completed ? {completedAt:new Date().toISOString()} : {})});
      tx.create(receipt, {fingerprint: hash, runId, stopId, status});
      return {status: 'accepted', operationId};
    }

    if (action === 'listRuns') {
      const driverId = driver.get('status') === 'active' ? uid : input.driverId ? text(input.driverId, 64) : null;
      const status = input.status ? text(input.status, 32) : null;

      let query: FirebaseFirestore.Query = db.collection(root).orderBy('createdAt', 'desc').limit(50);
      if (driverId) {
        query = query.where('driverId', '==', driverId);
      }
      if (status) {
        query = query.where('status', '==', status);
      }

      const snapshot = await tx.get(query);
      const runs = snapshot.docs.map((d) => d.data());
      return { runs };
    }

    throw new HttpsError('invalid-argument', 'Unknown delivery action');
  });
}

export async function getDriverWorkspaces(db: Firestore, request: AuthRequest) {
  const uid = requireHuman(request);
  return db.runTransaction(async tx => {
    const assignments = await tx.get(db.collection(`driverWorkspaces/${uid}/assignments`).limit(50));
    const workspaces = [];
    for (const doc of assignments.docs) {
      const [merchant, driver] = await Promise.all([
        tx.get(db.doc(`merchants/${doc.id}`)), tx.get(db.doc(`merchants/${doc.id}/drivers/${uid}`)),
      ]);
      if (merchant.get('status') === 'active' && driver.get('status') === 'active') {
        workspaces.push({merchantId: doc.id, warehouseId: driver.get('warehouseId'), driverName: driver.get('driverName')});
      }
    }
    return {workspaces};
  });
}
