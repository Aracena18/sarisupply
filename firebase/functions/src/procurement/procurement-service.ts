import { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';
import { canonical } from '../checkout/checkout-validation';

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

async function requirePurchasingCatalog(db: Firestore, tx: Transaction, merchantId: string,
    warehouseId: string, lines: Input[]) {
  const root = `merchants/${merchantId}`;
  const warehouse = await tx.get(db.doc(`${root}/warehouses/${warehouseId}`));
  if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
  for (const line of lines) {
    const product = await tx.get(db.doc(`${root}/products/${line.productId}`));
    if (product.get('active') !== true || product.get('sku') !== line.sku || product.get('name') !== line.productName) {
      throw new HttpsError('failed-precondition','Refresh the purchasing catalog');
    }
  }
}

export async function readProcurementWorkspace(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const kind = text(input.kind,32);
  return db.runTransaction(async tx => {
    const uid = requireHuman(request), authorization = authz(db,tx);
    const membership = await authorization.requireActiveMembership(uid,merchantId);
    const owner = membership.role === 'owner' && membership.allBranches;
    const branchId = requireDocumentId(input.branchId,'branch ID');
    await authorization.requireBranchAccess(uid,merchantId,branchId);
    const root = `merchants/${merchantId}`;
    let query: FirebaseFirestore.Query;
    if (kind === 'restockProposals') {
      query = db.collection(`${root}/${kind}`);
      if (!owner) query = query.where('branchId','==',branchId);
    } else if (kind === 'warehouses') query = db.collection(`${root}/warehouses`).where('active','==',true);
    else if (owner && kind === 'purchaseOrders') query = db.collection(`${root}/purchaseOrders`);
    else if (owner && kind === 'warehouseStock') query = db.collection(`${root}/warehouses/${requireDocumentId(input.warehouseId,'warehouse ID')}/stock`);
    else throw new HttpsError('permission-denied','Owner workspace required');
    const records = await tx.get(query.limit(51));
    return {records:records.docs.slice(0,50).map(d => ({...d.data(),id:d.id})),hasMore:records.size>50,actorId:uid,canManagePurchasing:owner};
  });
}

export async function manageWarehouses(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId,'merchant ID');
  const warehouseId = requireDocumentId(input.warehouseId,'warehouse ID');
  const action = text(input.action,20), root = `merchants/${merchantId}/warehouses/${warehouseId}`;
  return db.runTransaction(async tx => {
    await authz(db,tx).requireOwner(requireHuman(request),merchantId);
    if (action === 'save') {
      const warehouse = input.warehouse as Input;
      const saved = {id:warehouseId,name:text(warehouse?.name,120),code:text(warehouse?.code,40),address:text(warehouse?.address,250,true),active:true};
      tx.set(db.doc(root),saved,{merge:true});
      return {status:'saved',warehouseId};
    }
    if (action !== 'adjust') throw new HttpsError('invalid-argument','Unknown warehouse action');
    const productId = requireDocumentId(input.productId,'product ID'), operationId = requireDocumentId(input.operationId,'operation ID');
    const delta = integer(input.delta,-1000000000), reason = text(input.reason,200);
    if (delta === 0) throw new HttpsError('invalid-argument','Adjustment cannot be zero');
    const receipt = db.doc(`merchants/${merchantId}/procurementOperations/${operationId}`);
    const fingerprint = canonical({warehouseId,productId,delta,reason}), previous = await tx.get(receipt);
    if (previous.exists) {
      if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists','Adjustment changed');
      return {status:'duplicate',warehouseId};
    }
    const warehouse = await tx.get(db.doc(root));
    if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
    const ref = db.doc(`${root}/stock/${productId}`), stock = await tx.get(ref);
    const physicalQuantity = integer(stock.get('physicalQuantity')??0)+delta;
    const reservedQuantity = integer(stock.get('reservedQuantity')??0);
    if (physicalQuantity < reservedQuantity) throw new HttpsError('failed-precondition','Adjustment would consume reserved stock');
    integer(physicalQuantity);
    tx.set(ref,{warehouseId,productId,physicalQuantity,reservedQuantity},{merge:true});
    tx.create(receipt,{fingerprint,warehouseId,productId,delta,actor:requireHuman(request)});
    return {status:'adjusted',warehouseId};
  });
}

// -------------------------------------------------------------
// Suppliers
// -------------------------------------------------------------

export async function manageSuppliers(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const action = text(input.action, 20);

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    const uid = requireHuman(request);
    if (action === 'list') await authorization.requireActiveMembership(uid, merchantId);
    else await authorization.requireOwner(uid, merchantId);

    const root = `merchants/${merchantId}/suppliers`;

    if (action === 'save') {
      const supplierData = input.supplier as Record<string, unknown>;
      const supplierId = requireDocumentId(supplierData?.id, 'supplier ID');
      const name = text(supplierData.name, 120);
      const contactPerson = text(supplierData.contactPerson, 100, true);
      const phone = text(supplierData.phone, 32, true);
      const email = text(supplierData.email, 100, true);
      const address = text(supplierData.address, 200, true);
      const leadTimeDays = integer(supplierData.leadTimeDays ?? 1, 1, 365);
      const active = (supplierData.active as boolean) ?? true;

      const docRef = db.doc(`${root}/${supplierId}`);
      tx.set(docRef, {
        id: supplierId,
        name,
        contactPerson,
        phone,
        email,
        address,
        leadTimeDays,
        active,
        updatedAt: new Date().toISOString(),
      }, { merge: true });

      return { status: 'saved', supplierId };
    }

    if (action === 'list') {
      const snap = await tx.get(db.collection(root).where('active', '==', true).limit(50));
      const suppliers = snap.docs.map((d) => d.data());
      return { suppliers };
    }

    throw new HttpsError('invalid-argument', 'Unknown supplier action');
  });
}

// -------------------------------------------------------------
// Purchase Orders & Supplier Receiving
// -------------------------------------------------------------

export async function managePurchaseOrders(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const action = text(input.action, 20);

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    const uid = requireHuman(request);
    await authorization.requireOwner(uid, merchantId);

    const root = `merchants/${merchantId}/purchaseOrders`;

    if (action === 'create') {
      const poData = input.po as Record<string, unknown>;
      const poId = requireDocumentId(poData?.id, 'PO ID');
      const supplierId = requireDocumentId(poData?.supplierId, 'supplier ID');
      const supplierName = text(poData?.supplierName, 120);
      const warehouseId = requireDocumentId(poData?.warehouseId, 'warehouse ID');
      const notes = text(poData?.notes ?? '', 200, true);
      const lines = (poData?.lines as Array<Record<string, unknown>> ?? []).map((l) => ({
        productId: requireDocumentId(l.productId, 'product ID'),
        productName: text(l.productName, 120),
        sku: text(l.sku, 64),
        quantity: integer(l.quantity, 1),
        unitCostCentavos: integer(l.unitCostCentavos, 0),
        quantityReceived: 0,
      }));

      const docRef = db.doc(`${root}/${poId}`);
      if (!lines.length || lines.length > 20 || new Set(lines.map(l => l.productId)).size !== lines.length) {
        throw new HttpsError('invalid-argument', 'Select unique purchase items');
      }
      const fingerprint = canonical({supplierId,supplierName,warehouseId,notes,lines});
      const previous = await tx.get(docRef);
      if (previous.exists) {
        if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists','Purchase order ID changed');
        return {status:'duplicate',poId};
      }
      const supplier = await tx.get(db.doc(`merchants/${merchantId}/suppliers/${supplierId}`));
      if (supplier.get('active') !== true || supplier.get('name') !== supplierName) {
        throw new HttpsError('failed-precondition','Supplier is unavailable; refresh purchasing');
      }
      await requirePurchasingCatalog(db,tx,merchantId,warehouseId,lines);
      tx.create(docRef, {
        fingerprint,
        id: poId,
        supplierId,
        supplierName,
        warehouseId,
        status: 'submitted',
        lines,
        notes,
        createdAt: new Date().toISOString(),
      });

      return { status: 'created', poId };
    }

    if (action === 'receive') {
      const poId = requireDocumentId(input.poId, 'PO ID');
      const productId = requireDocumentId(input.productId, 'product ID');
      const qtyReceived = integer(input.quantityReceived, 1);
      const operationId = requireDocumentId(input.operationId, 'receiving operation ID');
      const receipt = db.doc(`merchants/${merchantId}/procurementOperations/${operationId}`);
      const previous = await tx.get(receipt);
      const batchNumber = text(input.batchNumber ?? '',80,true);
      const expiryDate = text(input.expiryDate ?? '',10,true);
      if (Boolean(batchNumber) !== Boolean(expiryDate) || (expiryDate &&
          (!/^\d{4}-\d{2}-\d{2}$/.test(expiryDate) || !Number.isFinite(Date.parse(expiryDate)) ||
           new Date(expiryDate).toISOString().slice(0,10) !== expiryDate))) {
        throw new HttpsError('invalid-argument','Provide a batch and valid expiry date together');
      }
      const fingerprint = canonical({poId,productId,qtyReceived,batchNumber,expiryDate});
      if (previous.exists) {
        if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists','Receiving operation changed');
        return {...previous.get('result'),status:'duplicate'};
      }

      const docRef = db.doc(`${root}/${poId}`);
      const poDoc = await tx.get(docRef);
      if (!poDoc.exists) throw new HttpsError('not-found', 'Purchase order not found');

      const po = poDoc.data()!;
      if (!['submitted','partiallyReceived'].includes(po.status)) throw new HttpsError('failed-precondition','Purchase order is not receivable');
      const ordered = (po.lines as Input[]).find(l => l.productId === productId);
      if (!ordered || integer(ordered.quantityReceived) + qtyReceived > integer(ordered.quantity)) throw new HttpsError('failed-precondition','Receiving exceeds ordered quantity');
      const lines = (po.lines as Array<Record<string, unknown>>).map((l) => {
        if (l.productId === productId) {
          return {
            ...l,
            quantityReceived: ((l.quantityReceived as number) || 0) + qtyReceived,
          };
        }
        return l;
      });

      const allReceived = lines.every((l) => (l.quantityReceived as number) >= (l.quantity as number));
      const newStatus = allReceived ? 'completed' : 'partiallyReceived';

      // Update warehouse stock
      const whStockRef = db.doc(`merchants/${merchantId}/warehouses/${po.warehouseId}/stock/${productId}`);
      const whDoc = await tx.get(whStockRef);
      const currentPhys = integer(whDoc.get('physicalQuantity') ?? 0);
      integer(currentPhys + qtyReceived);
      const warehouse = await tx.get(db.doc(`merchants/${merchantId}/warehouses/${po.warehouseId}`));
      if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');
      const currentRes = (whDoc.data()?.reservedQuantity as number) || 0;

      tx.update(docRef, { lines, status: newStatus });

      tx.set(whStockRef, {
        warehouseId: po.warehouseId,
        productId,
        physicalQuantity: currentPhys + qtyReceived,
        reservedQuantity: currentRes,
        unitCostCentavos: integer(ordered.unitCostCentavos),
        costBasis: 'lastPurchase',
        updatedAt: new Date().toISOString(),
      }, { merge: true });

      const result = { status: newStatus, poId, quantityReceived: qtyReceived };
      tx.create(receipt,{fingerprint,result,poId,productId,warehouseId:po.warehouseId,
        quantityReceived:qtyReceived,unitCostCentavos:integer(ordered.unitCostCentavos),batchNumber,expiryDate,actor:uid});
      if (batchNumber) tx.create(db.doc(`merchants/${merchantId}/warehouses/${po.warehouseId}/batches/${operationId}`), {
        id:operationId,productId,batchNumber,expiryDate,quantity:qtyReceived,poId,
        unitCostCentavos:integer(ordered.unitCostCentavos),receivedAt:new Date().toISOString(),
      });
      return result;
    }

    throw new HttpsError('invalid-argument', 'Unknown PO action');
  });
}

// -------------------------------------------------------------
// Restock Proposals & Owner Review
// -------------------------------------------------------------

export async function manageRestockProposals(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const action = text(input.action, 20);

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    const root = `merchants/${merchantId}/restockProposals`;

    if (action === 'submit') {
      const uid = requireHuman(request);
      await authorization.requireActiveMembership(uid, merchantId);

      const proposalData = input.proposal as Record<string, unknown>;
      const proposalId = requireDocumentId(proposalData?.id, 'proposal ID');
      const branchId = requireDocumentId(proposalData?.branchId, 'branch ID');
      await authorization.requireBranchAccess(uid, merchantId, branchId);
      const warehouseId = requireDocumentId(proposalData?.warehouseId, 'warehouse ID');
      const notes = text(proposalData?.notes ?? '', 200, true);
      const lines = (proposalData?.lines as Array<Record<string, unknown>> ?? []).map((l) => ({
        productId: requireDocumentId(l.productId, 'product ID'),
        productName: text(l.productName, 120),
        sku: text(l.sku, 64),
        currentStock: integer(l.currentStock, -1000000000),
        suggestedQuantity: integer(l.suggestedQuantity, 1),
        approvedQuantity: 0,
        pickedQuantity: 0,
      }));

      const docRef = db.doc(`${root}/${proposalId}`);
      if (!lines.length || lines.length > 20 || new Set(lines.map(l => l.productId)).size !== lines.length) throw new HttpsError('invalid-argument','Select unique restock items');
      const fingerprint = canonical({branchId,warehouseId,notes,lines});
      const previous = await tx.get(docRef);
      if (previous.exists) {
        if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists','Proposal ID changed');
        return {status:'duplicate',proposalId};
      }
      await requirePurchasingCatalog(db,tx,merchantId,warehouseId,lines);
      tx.create(docRef, {
        fingerprint,
        id: proposalId,
        branchId,
        warehouseId,
        status: 'pendingApproval',
        lines,
        notes,
        requestedAt: new Date().toISOString(),
      });

      return { status: 'submitted', proposalId };
    }

    if (action === 'review') {
      // STRICT REQUIREMENT: Owner role required for approving replenishment
      const uid = requireHuman(request);
      await authorization.requireOwner(uid, merchantId);

      const proposalId = requireDocumentId(input.proposalId, 'proposal ID');
      const approved = (input.approved as boolean) ?? false;
      const rejectionReason = input.rejectionReason ? text(input.rejectionReason, 200) : null;

      const docRef = db.doc(`${root}/${proposalId}`);
      const propDoc = await tx.get(docRef);
      if (!propDoc.exists) throw new HttpsError('not-found', 'Restock proposal not found');

      const proposal = propDoc.data()!;
      const reviewFingerprint = canonical({approved,adjustedLines:input.adjustedLines??null,rejectionReason});
      if (proposal.reviewFingerprint === reviewFingerprint) return {status:proposal.status,proposalId};
      if (proposal.status !== 'pendingApproval') throw new HttpsError('failed-precondition','Proposal already reviewed');
      if (!approved) {
        tx.update(docRef, {
          reviewFingerprint,
          status: 'rejected',
          reviewedBy: uid,
          reviewedAt: new Date().toISOString(),
          rejectionReason: rejectionReason ?? 'Rejected by owner',
        });
        return { status: 'rejected', proposalId };
      }

      // If approved, reserve warehouse stock
      const rawAdjusted = (input.adjustedLines as Array<Record<string, unknown>> | undefined) ?? (proposal.lines as Array<Record<string, unknown>>);
      const lines = rawAdjusted.map((l: Record<string, unknown>) => {
        const original = (proposal.lines as Input[]).find(line => line.productId === l.productId);
        if (!original) throw new HttpsError('invalid-argument','Unknown proposal product');
        const approvedQty = integer(input.adjustedLines == null ? original.suggestedQuantity : l.approvedQuantity, 0);
        return {
          productId: original.productId as string,
          productName: original.productName as string,
          sku: original.sku as string,
          currentStock: original.currentStock as number,
          suggestedQuantity: original.suggestedQuantity as number,
          approvedQuantity: approvedQty,
          pickedQuantity: 0,
        };
      });
      if (lines.length !== proposal.lines.length || new Set(lines.map(l => l.productId)).size !== lines.length || !lines.some(l => l.approvedQuantity>0)) throw new HttpsError('invalid-argument','Approval must match proposal items');

      const writes: (() => void)[] = [];
      for (const line of lines) {
        const productId = line.productId;
        const approvedQty = line.approvedQuantity;
        if (approvedQty <= 0) continue;

        const whStockRef = db.doc(`merchants/${merchantId}/warehouses/${proposal.warehouseId}/stock/${productId}`);
        const whDoc = await tx.get(whStockRef);
        const phys = (whDoc.data()?.physicalQuantity as number) || 0;
        const res = (whDoc.data()?.reservedQuantity as number) || 0;
        if (phys - res < approvedQty) throw new HttpsError('failed-precondition','Insufficient unreserved warehouse stock');

        writes.push(() => tx.set(whStockRef, {
          warehouseId: proposal.warehouseId,
          productId,
          physicalQuantity: phys,
          reservedQuantity: res + approvedQty,
          updatedAt: new Date().toISOString(),
        }, { merge: true }));
      }

      for (const write of writes) write();
      tx.update(docRef, {
        reviewFingerprint,
        status: 'approved',
        lines,
        reviewedBy: uid,
        reviewedAt: new Date().toISOString(),
      });

      return { status: 'approved', proposalId };
    }

    if (action === 'fulfill') {
      const uid = requireHuman(request);
      await authorization.requireOwner(uid, merchantId);

      const proposalId = requireDocumentId(input.proposalId, 'proposal ID');
      const stage = text(input.stage, 20); // 'pick' or 'pack'

      const docRef = db.doc(`${root}/${proposalId}`);
      const propDoc = await tx.get(docRef);
      if (!propDoc.exists) throw new HttpsError('not-found', 'Restock proposal not found');
      const proposal = propDoc.data()!;

      if (stage === 'startPick') {
        if (proposal.status === 'picking') return {status:'picking',proposalId};
        if (proposal.status !== 'approved') throw new HttpsError('failed-precondition','Approve before picking');
        tx.update(docRef,{status:'picking'});
        return {status:'picking',proposalId};
      }

      if (stage === 'pick') {
        const pickFingerprint = canonical(input.pickedLines ?? null);
        if (proposal.pickFingerprint === pickFingerprint && ['picked','packed'].includes(proposal.status)) return {status:'picked',proposalId};
        if (!['approved','picking'].includes(proposal.status)) throw new HttpsError('failed-precondition','Approve proposal before picking');
        const pickedLines = (input.pickedLines as Array<Record<string, unknown>> ?? proposal.lines).map((l) => ({
          ...((proposal.lines as Input[]).find(line => line.productId === l.productId) ?? {}),
          pickedQuantity: integer(input.pickedLines == null ? l.approvedQuantity : l.pickedQuantity, 0),
        }));
        if (pickedLines.length !== proposal.lines.length || new Set(pickedLines.map((l:Input) => l.productId)).size !== pickedLines.length || pickedLines.some((l:Input) => typeof l.productId !== 'string' || integer(l.pickedQuantity) > integer(l.approvedQuantity))) throw new HttpsError('invalid-argument','Picked quantities exceed approval');
        tx.update(docRef, {
          pickFingerprint,
          status: 'picked',
          lines: pickedLines,
        });
        return { status: 'picked', proposalId };
      }

      if (stage === 'pack') {
        const packageCode = text(input.packageCode, 64);
        const sealNotes = text(input.sealNotes ?? '', 200, true);
        if (proposal.status === 'packed' && proposal.packageCode === packageCode && proposal.sealNotes === sealNotes) return {status:'packed',proposalId,packageCode};
        if (proposal.status !== 'picked') throw new HttpsError('failed-precondition','Pick proposal before packing');
        const warehouse = await tx.get(db.doc(`merchants/${merchantId}/warehouses/${proposal.warehouseId}`));
        if (warehouse.get('active') !== true) throw new HttpsError('failed-precondition','Warehouse is unavailable');

        // Deduct physical and reserved stock from warehouse
        const writes: (() => void)[] = [];
        const manifestItems: Input[] = [];
        for (const line of proposal.lines as Array<Record<string, unknown>>) {
          const productId = line.productId as string;
          const qty = integer(line.pickedQuantity);
          const approved = integer(line.approvedQuantity);
          if (approved === 0) continue;

          const whStockRef = db.doc(`merchants/${merchantId}/warehouses/${proposal.warehouseId}/stock/${productId}`);
          const whDoc = await tx.get(whStockRef);
          const phys = (whDoc.data()?.physicalQuantity as number) || 0;
          const res = (whDoc.data()?.reservedQuantity as number) || 0;
          if (phys < qty || res < approved) throw new HttpsError('failed-precondition','Warehouse stock needs review');
          if (qty > 0) manifestItems.push({productId,productName:line.productName,sku:line.sku,
            quantityOrdered:qty,unitCostCentavos:whDoc.get('unitCostCentavos') ?? null});

          writes.push(() => tx.set(whStockRef, {
            warehouseId: proposal.warehouseId,
            productId,
            physicalQuantity: phys - qty,
            reservedQuantity: res - approved,
            updatedAt: new Date().toISOString(),
          }, { merge: true }));
        }

        const manifestId = `manifest-${proposalId}`;
        requireDocumentId(manifestId,'manifest ID');
        const branch = await tx.get(db.doc(`merchants/${merchantId}/branches/${proposal.branchId}`));
        if (branch.get('status') !== 'active') throw new HttpsError('failed-precondition','Destination branch is unavailable');
        for (const write of writes) write();
        tx.create(db.doc(`merchants/${merchantId}/packageManifests/${manifestId}`), {
          id:manifestId,proposalId,warehouseId:proposal.warehouseId,destinationId:proposal.branchId,
          destinationName:branch.get('name') ?? proposal.branchId,
          destinationAddress:branch.get('address') ?? '',items:manifestItems,
          status:'packed',packageCode,sealNotes,packedBy:uid,packedAt:new Date().toISOString(),
        });
        tx.update(docRef, {
          status: 'packed',
          packageCode,
          sealNotes,
          packedAt: new Date().toISOString(),
        });
        return { status: 'packed', proposalId, packageCode };
      }

      throw new HttpsError('invalid-argument', 'Unknown fulfillment stage');
    }

    throw new HttpsError('invalid-argument', 'Unknown restock proposal action');
  });
}
