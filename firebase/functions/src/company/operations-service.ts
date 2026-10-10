import { createHash } from 'node:crypto';
import { FieldPath, FieldValue, Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthRequest, AuthorizationService, CompanyRole, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';

type Data = Record<string, any>;
type Write = () => void;
const fail = (message: string): never => { throw new HttpsError('failed-precondition', message); };
const deny = (): never => { throw new HttpsError('permission-denied', 'Access denied'); };
function text(v: unknown, max = 200): string {
  if (typeof v !== 'string' || !v.trim() || v.trim().length > max) throw new HttpsError('invalid-argument', 'Enter a valid value');
  return v.trim();
}
function integer(v: unknown, min = 0, max = 100000000): number {
  if (typeof v !== 'number' || !Number.isSafeInteger(v) || v < min || v > max) throw new HttpsError('invalid-argument', 'Enter a valid whole number');
  return v;
}
// Optional company product photo: preset/custom HTTPS URL only. Empty clears,
// omitted preserves. Managed Cloudinary uploads remain unsupported for company
// products; the client cannot claim an asset by supplying provider metadata.
function photoUrl(v: unknown): string | null {
  if (typeof v !== 'string' || v.length > 2048) throw new HttpsError('invalid-argument', 'Use an HTTPS photo URL');
  if (!v.trim()) return null;
  let url: URL;
  try { url = new URL(v.trim()); } catch { throw new HttpsError('invalid-argument', 'Use an HTTPS photo URL'); }
  if (url.protocol !== 'https:' || url.username || url.password) throw new HttpsError('invalid-argument', 'Use an HTTPS photo URL');
  return url.href;
}
function lines(v: unknown): Data[] {
  if (!Array.isArray(v) || !v.length || v.length > 20 || !v.every(l => l && typeof l === 'object')) throw new HttpsError('invalid-argument', 'Choose 1–20 items');
  const ids = v.map(l => requireDocumentId(l.productId, 'product ID'));
  if (new Set(ids).size !== ids.length) throw new HttpsError('invalid-argument', 'Choose each product once');
  return v;
}
export function deliveryQuantities(packed: number, delivered: number, returned: number): void {
  integer(packed); integer(delivered); integer(returned);
  if (delivered + returned !== packed) fail('Account for every packed unit as delivered or returned');
}
export function stockReservation(physical: number, reserved: number, delta: number): number {
  integer(physical); integer(reserved);
  const next = reserved + delta;
  if (!Number.isSafeInteger(next) || next < 0 || next > physical) fail('Available warehouse stock changed. Refresh the order.');
  return next;
}
async function authorize(db: Firestore, tx: Transaction, request: AuthRequest, input: Data) {
  if (input.authorizationVersion !== 1) throw new HttpsError('invalid-argument', 'Unsupported contract version');
  const uid = requireHuman(request);
  const context = input.context as Data;
  const companyId = requireDocumentId(input.companyId, 'company ID');
  // Memoize document reads only inside this transaction attempt. A retry or
  // another command must re-read current authority, including revocations.
  const documents = new Map<string, Promise<FirebaseFirestore.DocumentSnapshot>>();
  const read = (path: string) => {
    let snapshot = documents.get(path);
    if (!snapshot) { snapshot = tx.get(db.doc(path)); documents.set(path, snapshot); }
    return snapshot;
  };
  const company = await read(`companies/${companyId}`);
  if (company.get('status') !== 'active' || company.get('companyId')!==companyId || company.get('authorizationVersion') !== 1) deny();
  const policy = new AuthorizationService(async p => (await read(p)).data() ?? null);
  if (context?.kind === 'store') {
    const merchantId = requireDocumentId(context.merchantId, 'store ID');
    const branchId = requireDocumentId(context.branchId, 'branch ID');
    await policy.requireOwner(uid, merchantId);
    await policy.requireBranchAccess(uid, merchantId, branchId);
    return { uid, companyId, company, role: 'storeOwner', merchantId, branchId, policy };
  }
  if (context?.kind !== 'company' || context.companyId !== companyId || !['companyOwner','warehouseOperations','rider'].includes(context.role)) deny();
  await policy.requireCompanyRole(request, companyId, context.role as CompanyRole,
    input.warehouseId === undefined ? undefined : requireDocumentId(input.warehouseId, 'warehouse ID'));
  return { uid, companyId, company, role: context.role as string, merchantId: '', branchId: '', policy };
}

async function activeRider(db:Firestore,tx:Transaction,companyId:string,uid:string,warehouseId:string) {
  const member=await tx.get(db.doc(`companies/${companyId}/memberships/${uid}`));
  const role=await tx.get(db.doc(`companies/${companyId}/memberships/${uid}/roles/rider`));
  const ids=role.get('scope.warehouseIds');
  if(member.get('companyId')!==companyId||member.get('userId')!==uid||member.get('status')!=='active'||!Number.isSafeInteger(member.get('revision'))||member.get('revision')<1||role.get('companyId')!==companyId||role.get('userId')!==uid||role.get('role')!=='rider'||role.get('status')!=='active'||!Number.isSafeInteger(role.get('revision'))||role.get('revision')<1||role.get('scope.kind')!=='warehouses'||!Array.isArray(ids)||!ids.includes(warehouseId))fail('Choose an active rider assigned to this warehouse');
  return member;
}

export async function discoverSupplyingCompany(db: Firestore, request: AuthRequest, input: Data) {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'store ID');
  const policy = new AuthorizationService(async p => (await db.doc(p).get()).data() ?? null);
  await policy.requireOwner(uid, merchantId);
  const companies = await db.collection('companies').where('status','==','active').limit(2).get();
  if (companies.size !== 1) fail('A supplying company is not available yet');
  return { authorizationVersion: 1, companyId: companies.docs[0].id, name: companies.docs[0].get('name') };
}

// Selling projections contain no internal warehouse ledger or acquisition costs.
function sellingProduct(d: FirebaseFirestore.DocumentSnapshot, availability?: string): Data {
  return {id:d.id,name:d.get('name'),sku:d.get('sku'),unit:d.get('unit'),
    priceCentavos:d.get('priceCentavos'),revision:d.get('revision'),active:d.get('active')===true,
    ...(typeof d.get('imageUrl') === 'string' && d.get('imageUrl') ? {imageUrl:d.get('imageUrl')} : {}),
    ...(availability ? {availability} : {})};
}
function orderingRoot(a: {merchantId:string,branchId:string,companyId:string}): string {
  return `merchants/${a.merchantId}/branches/${a.branchId}/companyOrdering/${a.companyId}`;
}
export async function readCompanyOperations(db: Firestore, request: AuthRequest, input: Data) {
  return db.runTransaction(async tx => {
    const a = await authorize(db, tx, request, input);
    const root = `companies/${a.companyId}`;
    const kind = text(input.kind, 30);
    const cursor = input.cursor === undefined ? undefined : requireDocumentId(input.cursor, 'cursor');
    if (['orderingPreferences','productMappings'].includes(kind)) {
      if(a.role!=='storeOwner')deny();
      if(kind==='orderingPreferences') {
        const docs=await tx.getAll(db.doc(orderingRoot(a)),db.doc(`merchants/${a.merchantId}/branches/${a.branchId}`));
        const saved=docs[0].data()??{};const branch=docs[1].data()??{};const contacts=branch.contactDetails??{};
        return {authorizationVersion:1,companyId:a.companyId,records:[{id:a.companyId,
          address:saved.address??branch.address??'',contact:saved.contact??contacts.name??contacts.contactPerson??'',
          phone:saved.phone??contacts.phone??'',warehouseId:saved.warehouseId??null}],hasMore:false,nextCursor:null,source:'server'};
      }
      let q:FirebaseFirestore.Query=db.collection(`${orderingRoot(a)}/productMappings`).orderBy(FieldPath.documentId()).limit(26);
      if(cursor)q=q.startAfter(cursor);const page=await tx.get(q);
      return {authorizationVersion:1,companyId:a.companyId,records:page.docs.slice(0,25).map(d=>({...d.data(),id:d.id})),
        hasMore:page.size>25,nextCursor:page.size>25?page.docs[24].id:null,source:'server'};
    }
    if(kind==='catalog'||kind==='selectedProducts') {
      if(a.role!=='storeOwner')deny();
      const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID');
      const warehouse=await tx.get(db.doc(`${root}/warehouses/${warehouseId}`));
      if(warehouse.get('status')!=='active'||warehouse.get('companyId')!==a.companyId||warehouse.get('warehouseId')!==warehouseId)fail('Warehouse unavailable');
      let docs:FirebaseFirestore.DocumentSnapshot[];let hasMore=false;let nextCursor:string|null=null;
      if(kind==='selectedProducts') {
        if(!Array.isArray(input.productIds)||!input.productIds.length||input.productIds.length>20)throw new HttpsError('invalid-argument','Choose 1–20 items');
        const ids=input.productIds.map((id:unknown)=>requireDocumentId(id,'product ID'));
        if(new Set(ids).size!==ids.length)throw new HttpsError('invalid-argument','Choose each product once');
        docs=await tx.getAll(...ids.map((id:string)=>db.doc(`${root}/products/${id}`)));
      } else {
        let q:FirebaseFirestore.Query=db.collection(`${root}/products`).orderBy(FieldPath.documentId()).limit(26);
        if(cursor)q=q.startAfter(cursor);const page=await tx.get(q);docs=page.docs.slice(0,25);
        hasMore=page.size>25;nextCursor=hasMore?page.docs[24].id:null;
      }
      // Cursor advances over all examined products, including inactive/nonmatching ones.
      // This supports existing catalogs without a blocking backfill or new index.
      const search=typeof input.search==='string'?input.search.trim().toLowerCase():'';
      if(search.length>120)throw new HttpsError('invalid-argument','Search is too long');
      const visible=docs.filter(d=>kind==='selectedProducts'||(d.get('active')===true&&
        (!search||`${d.get('name')??''} ${d.get('sku')??''}`.toLowerCase().includes(search))));
      const stocks=visible.length?await tx.getAll(...visible.map(d=>db.doc(`${root}/warehouses/${warehouseId}/stock/${d.id}`))):[];
      return {authorizationVersion:1,companyId:a.companyId,records:visible.map((d,i)=>sellingProduct(d,
        (stocks[i].get('physical')??0)-(stocks[i].get('reserved')??0)>0?'inStock':'outOfStock')),
        hasMore,nextCursor,source:'server'};
    }
    let query: FirebaseFirestore.Query;
    if(kind==='paymentInstructions'){if(a.role==='rider')deny();return{authorizationVersion:1,companyId:a.companyId,records:[{id:a.companyId,instructions:a.company.get('paymentInstructions')??''}],hasMore:false,nextCursor:null,source:'server',verifiedAt:new Date().toISOString()};}
    if (kind === 'products') {
      if (a.role === 'rider') deny();
      query = db.collection(`${root}/products`);
    } else if (kind === 'warehouses') {
      if (a.role === 'rider') deny();
      const snap = await tx.get(db.collection(`${root}/warehouses`).orderBy(FieldPath.documentId()).limit(101));
      const records: Data[] = [];
      for (const d of snap.docs) {
        if (d.get('status') !== 'active') continue;
        if (a.role !== 'storeOwner') {
          try { await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,d.id); }
          catch (e) { if (e instanceof HttpsError && e.code === 'permission-denied') continue; throw e; }
        }
        records.push({ id:d.id,name:d.get('name'),address:d.get('address') ?? '' });
      }
      return { authorizationVersion:1,companyId:a.companyId,records,hasMore:snap.size>100,nextCursor:null,source:'server',verifiedAt:new Date().toISOString() };
    } else if (kind === 'stock') {
      if (a.role === 'storeOwner' || a.role === 'rider') deny();
      const warehouseId = requireDocumentId(input.warehouseId,'warehouse ID');
      await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,warehouseId);
      query = db.collection(`${root}/warehouses/${warehouseId}/stock`);
    } else if(kind==='itemRequests') {
      if(a.role==='rider')deny();
      if(a.role==='storeOwner')query=db.collection(`merchants/${a.merchantId}/branches/${a.branchId}/companyItemRequests`);
      else {const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID');await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,warehouseId);query=db.collection(`${root}/itemRequests`).where('warehouseId','==',warehouseId);}
    } else if (kind === 'orders') {
      if (a.role === 'rider') deny();
      if (a.role === 'storeOwner') query = db.collection(`merchants/${a.merchantId}/branches/${a.branchId}/companyOrders`);
      else {
        const warehouseId = requireDocumentId(input.warehouseId,'warehouse ID');
        await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,warehouseId);
        query = db.collection(`${root}/orders`).where('warehouseId','==',warehouseId);
      }
    } else if (kind === 'runs') {
      if (a.role === 'storeOwner') deny();
      if (a.role === 'rider') query = db.collection(`${root}/deliveryRuns`).where('driverId','==',a.uid);
      else {
        const warehouseId = requireDocumentId(input.warehouseId,'warehouse ID');
        await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,warehouseId);
        query = db.collection(`${root}/deliveryRuns`).where('warehouseId','==',warehouseId);
      }
    } else if (kind === 'riders') {
      if (a.role === 'storeOwner' || a.role === 'rider') deny();
      const warehouseId = requireDocumentId(input.warehouseId,'warehouse ID');
      await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,warehouseId);
      const refs = await tx.get(db.collection(`${root}/memberships`).orderBy(FieldPath.documentId()).limit(100));
      const records: Data[] = [];
      const roleRefs = refs.docs.map(ref => ref.ref.collection('roles').doc('rider'));
      const grants = roleRefs.length ? await tx.getAll(...roleRefs) : [];
      const active = refs.docs.filter((ref,i) => ref.get('status')==='active' &&
        grants[i].get('status')==='active' && grants[i].get('scope.warehouseIds')?.includes(warehouseId));
      const users = active.length ? await tx.getAll(...active.map(ref => db.doc(`users/${ref.id}`))) : [];
      for (const [i,ref] of active.entries()) {
        const user = users[i];
        records.push({id:ref.id,name:user.get('displayName') ?? ref.get('verifiedEmail') ?? user.get('email') ?? 'Rider'});
      }
      return {authorizationVersion:1,companyId:a.companyId,records,hasMore:refs.size===100,nextCursor:null,source:'server',verifiedAt:new Date().toISOString()};
    } else throw new HttpsError('invalid-argument','Unknown workspace');
    query = query.orderBy(FieldPath.documentId()).limit(26);
    if (cursor) query = query.startAfter(cursor);
    const page = await tx.get(query);
    const records: Data[] = [];
    const visible = page.docs.slice(0,25);
    const refs = kind === 'products' && a.role !== 'storeOwner' && input.warehouseId
      ? visible.map(d => db.doc(`${root}/warehouses/${input.warehouseId}/stock/${d.id}`))
      : ['orders','itemRequests'].includes(kind) && a.role === 'storeOwner'
      ? visible.filter(d => d.get('companyId') === a.companyId).map(d => db.doc(`${root}/${kind==='itemRequests'?'itemRequests':'orders'}/${d.id}`))
      : [];
    const related = new Map<string,FirebaseFirestore.DocumentSnapshot>();
    if (refs.length) for (const doc of await tx.getAll(...refs)) related.set(doc.id,doc);
    for (const d of visible) {
      let record = d.data();
      if (['orders','itemRequests'].includes(kind) && a.role==='storeOwner') {
        if (record.companyId!==a.companyId) continue;
        const order = related.get(d.id);
        record = order?.data() ?? {};
        if (record.merchantId!==a.merchantId || record.branchId!==a.branchId) deny();
      }
      if (kind==='runs' && a.role==='rider') {
        try{await a.policy.requireCompanyRole(request,a.companyId,'rider',record.warehouseId);}catch(e){if(e instanceof HttpsError&&e.code==='permission-denied')continue;throw e;}
      }
      if(kind==='products'&&a.role!=='storeOwner'&&input.warehouseId){const stock=related.get(d.id);record={...record,warehouseStock:stock?.data()??{physical:0,reserved:0,quarantined:0,inTransit:0}};}
      records.push(kind==='products'&&a.role==='storeOwner'?sellingProduct(d):{ ...record,id:d.id });
    }
    return {authorizationVersion:1,companyId:a.companyId,records,hasMore:page.size>25,nextCursor:page.size>25?page.docs[24].id:null,source:'server',verifiedAt:new Date().toISOString()};
  });
}

export async function mutateCompanyOperations(db: Firestore, request: AuthRequest, input: Data) {
  return db.runTransaction(async tx => {
    const a = await authorize(db,tx,request,input);
    const action = text(input.action,40);
    const operationId = requireDocumentId(input.operationId,'operation ID');
    const root = `companies/${a.companyId}`;
    const receipt = db.doc(`${root}/operations/${operationId}`);
    const previous = await tx.get(receipt);
    const hash = createHash('sha256').update(JSON.stringify({uid:a.uid,input})).digest('hex');
    if (previous.exists) {
      if (previous.get('fingerprint')!==hash) throw new HttpsError('already-exists','Operation ID has another payload');
      return previous.get('result');
    }
    const writes: Write[] = [];
    let targetId = ''; let status = 'accepted';
    const now = new Date().toISOString();
    const warehouseRole = async (warehouseId: string) => {
      if (!['companyOwner','warehouseOperations'].includes(a.role)) deny();
      await a.policy.requireCompanyRole(request,a.companyId,a.role as CompanyRole,warehouseId);
    };
    const stockChange = async (warehouseId:string, productId:string, physicalDelta:number, reserveDelta:number, quarantineDelta=0, transitDelta=0) => {
      const ref = db.doc(`${root}/warehouses/${warehouseId}/stock/${productId}`);
      const old = (await tx.get(ref)).data() ?? {physical:0,reserved:0,quarantined:0,revision:0};
      const physical = integer(old.physical)+physicalDelta;
      const quarantined = integer(old.quarantined ?? 0)+quarantineDelta;
      const inTransit=integer(old.inTransit??0)+transitDelta;integer(inTransit);
      const reserved = stockReservation(physical,integer(old.reserved),reserveDelta);
      integer(quarantined);
      writes.push(()=>tx.set(ref,{productId,physical,reserved,quarantined,inTransit,revision:integer(old.revision)+1}));
      writes.push(()=>tx.create(db.doc(`${root}/stockEvents/${operationId}-${productId}`),{operationId,warehouseId,productId,physicalDelta,reserveDelta,quarantineDelta,transitDelta,action,actorId:a.uid,occurredAt:now}));
    };
    if(['saveOrderingPreferences','saveProductMapping'].includes(action)) {
      if(a.role!=='storeOwner')deny();
      if(action==='saveOrderingPreferences') {
        const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID');
        const warehouse=await tx.get(db.doc(`${root}/warehouses/${warehouseId}`));
        if(warehouse.get('companyId')!==a.companyId||warehouse.get('status')!=='active')fail('Warehouse unavailable');
        targetId=a.companyId;writes.push(()=>tx.set(db.doc(orderingRoot(a)),{warehouseId,address:text(input.address,250),contact:text(input.contact,120),phone:text(input.phone,40)}));
      } else {
        targetId=requireDocumentId(input.retailProductId,'retail product');const productId=requireDocumentId(input.productId,'product ID');
        const docs=await tx.getAll(db.doc(`merchants/${a.merchantId}/products/${targetId}`),db.doc(`${root}/products/${productId}`));
        if(docs.some(d=>d.get('active')!==true))fail('Product unavailable');
        const factor=integer(input.retailUnitsPerCompanyUnit,1,10000);
        writes.push(()=>tx.set(db.doc(`${orderingRoot(a)}/productMappings/${targetId}`),{retailProductId:targetId,productId,retailUnitsPerCompanyUnit:factor,confirmedBy:a.uid,updatedAt:now}));
      }
    } else if(action==='submitItemRequest') {
      if(a.role!=='storeOwner')deny();const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID');
      const docs=await tx.getAll(db.doc(`${root}/warehouses/${warehouseId}`),db.doc(`merchants/${a.merchantId}`),db.doc(`merchants/${a.merchantId}/branches/${a.branchId}`));
      if(docs[0].get('companyId')!==a.companyId||docs[0].get('status')!=='active')fail('Warehouse unavailable');
      targetId=`request-${operationId}`;status='submitted';
      const request={id:targetId,companyId:a.companyId,merchantId:a.merchantId,branchId:a.branchId,warehouseId,
        storeName:docs[1].get('businessName')??docs[1].get('name')??'Store',branchName:docs[2].get('name')??'Branch',
        name:text(input.name,120),quantity:integer(input.quantity,1,100000),unit:text(input.unit,30),
        details:typeof input.details==='string'?input.details.trim().slice(0,200):'',
        contact:text(input.contact,120),phone:text(input.phone,40),status,revision:1,createdAt:now,updatedAt:now};
      writes.push(()=>tx.create(db.doc(`${root}/itemRequests/${targetId}`),request));
      writes.push(()=>tx.create(db.doc(`merchants/${a.merchantId}/branches/${a.branchId}/companyItemRequests/${targetId}`),{companyId:a.companyId}));
    } else if(action==='respondItemRequest'||action==='closeItemRequest') {
      targetId=requireDocumentId(input.requestId,'request ID');const ref=db.doc(`${root}/itemRequests/${targetId}`);const request=(await tx.get(ref)).data();
      if(!request)fail('Request unavailable');await warehouseRole(request!.warehouseId);
      if(integer(input.expectedRevision)!==request!.revision)fail('Request changed. Refresh before continuing.');
      if(request!.status==='closed')fail('Request is already closed');
      status=action==='respondItemRequest'?'responded':'closed';const response=text(input.response,600);
      const productId=action==='closeItemRequest'?(request!.productId??null):input.productId?requireDocumentId(input.productId,'product ID'):null;
      if(productId&&(await tx.get(db.doc(`${root}/products/${productId}`))).get('active')!==true)fail('Product unavailable');
      writes.push(()=>tx.update(ref,{status,response,productId,revision:request!.revision+1,updatedAt:now,respondedBy:a.uid}));
    } else if(action==='savePaymentInstructions'){if(a.role!=='companyOwner')deny();targetId=a.companyId;const instructions=text(input.instructions,600);writes.push(()=>tx.update(db.doc(root),{paymentInstructions:instructions}));
    } else if (action==='saveProduct') {
      if (a.role!=='companyOwner') deny();
      targetId = requireDocumentId(input.productId,'product ID');
      const ref = db.doc(`${root}/products/${targetId}`); const old = await tx.get(ref);
      if (integer(input.expectedRevision)!==(old.get('revision')??0)) fail('Product changed. Refresh before editing.');
      const unit = text(input.unit,30);const sku=text(input.sku,64);if(old.exists&&old.get('sku')!==sku)fail('SKU cannot change');const skuRef=db.doc(`${root}/skuRegistry/${createHash('sha256').update(sku.toUpperCase()).digest('hex')}`);const existingSku=await tx.get(skuRef);if(existingSku.exists&&existingSku.get('productId')!==targetId)fail('This SKU already belongs to another product');writes.push(()=>tx.set(skuRef,{productId:targetId}));
      if (old.exists && old.get('unit')!==unit) fail('The base unit cannot change after creation');
      const imageUrl = input.imageUrl === undefined ? (old.get('imageUrl') ?? null) : photoUrl(input.imageUrl);
      const product={id:targetId,name:text(input.name,120),sku,companyId:a.companyId,unit,priceCentavos:integer(input.priceCentavos,1),active:true,revision:(old.get('revision')??0)+1,
        ...(imageUrl ? {imageUrl} : {})};
      writes.push(()=>tx.set(ref,product));
    } else if (action==='receiveStock' || action==='correctStock' || action==='releaseQuarantine' || action==='writeOffTransit') {
      const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID'); await warehouseRole(warehouseId);
      if (action==='correctStock' || action==='releaseQuarantine' || action==='writeOffTransit') { if (a.role!=='companyOwner') deny(); }
      const productId=requireDocumentId(input.productId,'product ID'); targetId=productId;
      const product=await tx.get(db.doc(`${root}/products/${productId}`)); if (product.get('active')!==true) fail('Product unavailable');
      text(input.reference);
      const quantity=integer(input.quantity,action==='correctStock'?-100000000:1);
      if(action==='writeOffTransit')await stockChange(warehouseId,productId,0,0,0,-quantity);
      else if (action==='releaseQuarantine') await stockChange(warehouseId,productId,quantity,0,-quantity);
      else await stockChange(warehouseId,productId,quantity,0);
    } else if (action==='submitOrder') {
      if (a.role!=='storeOwner') deny();
      const paymentMethod=input.paymentMethod??'cashOnDelivery';
      if(!['cashOnDelivery','qr'].includes(paymentMethod))fail('Choose cash on delivery or QR payment');
      const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID');
      const warehouse=await tx.get(db.doc(`${root}/warehouses/${warehouseId}`));if(warehouse.get('status')!=='active'||warehouse.get('companyId')!==a.companyId||warehouse.get('warehouseId')!==warehouseId)fail('Warehouse unavailable');
      const branch=await tx.get(db.doc(`merchants/${a.merchantId}/branches/${a.branchId}`));
      const merchant=await tx.get(db.doc(`merchants/${a.merchantId}`));
      const company=await tx.get(db.doc(root));
      const paymentInstructions=company.get('paymentInstructions')??'';
      if(paymentMethod==='qr'&&(typeof paymentInstructions!=='string'||!paymentInstructions.trim()))fail('QR payment is not set up by this supplier');
      const items:Data[]=[];
      for(const line of lines(input.lines)) {
        const p=await tx.get(db.doc(`${root}/products/${line.productId}`));if(p.get('active')!==true)fail('Product unavailable');
        if(p.get('revision')!==integer(line.productRevision))fail('Wholesale price changed. Review the order again.');
        items.push({productId:p.id,name:p.get('name'),sku:p.get('sku'),unit:p.get('unit'),quantity:integer(line.quantity,1,100000),priceCentavos:integer(p.get('priceCentavos'),1)});
      }
      targetId=`order-${operationId}`;
      const order={id:targetId,companyId:a.companyId,merchantId:a.merchantId,branchId:a.branchId,warehouseId,
        storeName:merchant.get('businessName')??merchant.get('name')??'Store',branchName:branch.get('name')??'Store branch',
        address:text(input.address,250),contact:text(input.contact,120),phone:text(input.phone,40),notes:typeof input.notes==='string'?input.notes.slice(0,200):'',
        paymentMethod,paymentInstructions,lines:items,status:'submitted',revision:1,createdAt:now,updatedAt:now,receiptStatus:'awaitingDelivery',paymentConfirmedCentavos:0};
      writes.push(()=>tx.create(db.doc(`${root}/orders/${targetId}`),order));
      writes.push(()=>tx.set(db.doc(orderingRoot(a)),{warehouseId,address:order.address,contact:order.contact,phone:order.phone}));
      writes.push(()=>tx.create(db.doc(`merchants/${a.merchantId}/branches/${a.branchId}/companyOrders/${targetId}`),{companyId:a.companyId,orderId:targetId}));
      status='submitted';
    } else if (['acceptOrder','proposeOrder','confirmProposal','rejectOrder','cancelOrder','startPicking','packOrder','confirmReceipt','confirmQr'].includes(action)) {
      targetId=requireDocumentId(input.orderId,'order ID');const ref=db.doc(`${root}/orders/${targetId}`);const snapshot=await tx.get(ref);const order=snapshot.data();if(!order)fail('Order unavailable');
      if(a.role==='storeOwner') { if(order!.merchantId!==a.merchantId||order!.branchId!==a.branchId)deny(); }
      else await warehouseRole(order!.warehouseId);
      if(integer(input.expectedRevision)!==order!.revision)fail('Order changed. Refresh before continuing.');
      const patch:Data={revision:order!.revision+1,updatedAt:now};
      if(action==='acceptOrder'||action==='confirmProposal') {
        if(action==='acceptOrder') {if(a.role==='storeOwner')deny();if(order!.status!=='submitted')fail('Order is not awaiting acceptance');}
        else {if(a.role!=='storeOwner')deny();if(order!.status!=='awaitingConfirmation')fail('There is no proposal to confirm');}
        const accepted=action==='confirmProposal'?order!.proposedLines:order!.lines;
        for(const l of accepted)await stockChange(order!.warehouseId,l.productId,0,l.quantity);
        patch.status='accepted';patch.lines=accepted;patch.proposedLines=null;
      } else if(action==='proposeOrder') {
        if(a.role==='storeOwner')deny();if(!['submitted','picking'].includes(order!.status))fail('Order is not awaiting review');text(input.reason);if(order!.status==='picking')for(const l of order!.lines)await stockChange(order!.warehouseId,l.productId,0,-l.quantity);
        const proposed=lines(input.lines);if(proposed.length!==order!.lines.length)fail('Review all existing items');
        patch.proposedLines=order!.lines.map((l:Data)=>{const p=proposed.find(x=>x.productId===l.productId);if(!p)fail('Substitutions are not supported');return{...l,quantity:integer(p!.quantity,0,l.quantity),priceCentavos:integer(p!.priceCentavos,1)};}).filter((l:Data)=>l.quantity>0);
        if(!patch.proposedLines.length)fail('Reject an order when no items can be fulfilled');patch.status='awaitingConfirmation';patch.changeReason=text(input.reason);
      } else if(action==='rejectOrder'||action==='cancelOrder') {
        if(action==='rejectOrder'&&a.role==='storeOwner')deny();
        if(!['submitted','awaitingConfirmation','accepted'].includes(order!.status))fail('Picking has begun. Resolve this order with warehouse operations.');
        if(order!.status==='accepted')for(const l of order!.lines)await stockChange(order!.warehouseId,l.productId,0,-l.quantity);
        patch.status=action==='rejectOrder'?'rejected':'cancelled';patch.reason=text(input.reason);
      } else if(action==='startPicking'||action==='packOrder') {
        if(a.role==='storeOwner')deny();
        if(order!.status!==(action==='startPicking'?'accepted':'picking'))fail('Order stage changed');
        if(action==='packOrder') {const packed=lines(input.lines);if(packed.length!==order!.lines.length||order!.lines.some((l:Data)=>!packed.some(p=>p.productId===l.productId&&p.quantity===l.quantity)))fail('Every accepted quantity must be packed; report shortages before dispatch');patch.packageReference=text(input.packageReference,80);}
        patch.status=action==='startPicking'?'picking':'packed';
      } else if(action==='confirmQr') {
        if(a.role==='storeOwner')deny();if(order!.paymentMethod==='cashOnDelivery')fail('This order is set to cash on delivery');text(input.reference);const amount=integer(input.amountCentavos,1);const total=order!.lines.reduce((s:number,l:Data)=>s+l.quantity*l.priceCentavos,0);if((order!.paymentConfirmedCentavos??0)+amount>total)fail('Payment exceeds order value');
        patch.paymentConfirmedCentavos=(order!.paymentConfirmedCentavos??0)+amount;
        writes.push(()=>tx.create(db.doc(`${root}/paymentEvents/${operationId}`),{orderId:targetId,amountCentavos:amount,method:'manualQr',reference:input.reference,actorId:a.uid,occurredAt:now}));
      } else if(action==='confirmReceipt') {
        if(a.role!=='storeOwner')deny();if(order!.status!=='dispatched'||!order!.deliveryEvidence)fail('Await delivery evidence before confirming receipt');if(order!.receiptStatus!=='awaitingDelivery')fail('Receipt already confirmed');
        const accepted=lines(input.lines);if(accepted.length!==order!.lines.length)fail('Confirm every ordered item');
        const changes:Data[]=[];const ids=new Set<string>();let discrepancy=false;
        for(const l of order!.lines) {
          const incoming=accepted.find(x=>x.productId===l.productId);if(!incoming)fail('Confirm every ordered item');
          const quantity=integer(incoming!.quantity,0,l.quantity);const evidence=order!.deliveryEvidence.items.find((i:Data)=>i.productId===l.productId);if(quantity!==(evidence?.quantityDelivered??0))discrepancy=true;
          if(quantity===0)continue;
          const retailId=requireDocumentId(incoming!.retailProductId,'retail product');if(ids.has(retailId))fail('Use distinct retail products per line');ids.add(retailId);
          writes.push(()=>tx.set(db.doc(`${orderingRoot(a)}/productMappings/${retailId}`),{retailProductId:retailId,productId:l.productId,retailUnitsPerCompanyUnit:incoming!.retailUnitsPerCompanyUnit,confirmedBy:a.uid,updatedAt:now}));
          const factor=integer(incoming!.retailUnitsPerCompanyUnit,1,10000);const product=await tx.get(db.doc(`merchants/${a.merchantId}/products/${retailId}`));if(product.get('active')!==true)fail('Retail product is unavailable');
          const stockRef=db.doc(`merchants/${a.merchantId}/branches/${a.branchId}/stock/${retailId}`);const old=(await tx.get(stockRef)).data()??{quantity:0,revision:0};const delta=integer(quantity*factor);const position={productId:retailId,quantity:integer(old.quantity,-100000000)+delta,revision:integer(old.revision)+1,delta};changes.push(position);
          writes.push(()=>tx.set(stockRef,{quantity:position.quantity,revision:position.revision}));
        }
        if(changes.length) {
          const metaRef=db.doc(`merchants/${a.merchantId}/branches/${a.branchId}/inventoryMeta/stock`);const meta=await tx.get(metaRef);const sequence=integer(meta.get('sequence')??0)+1;
          writes.push(()=>tx.set(metaRef,{sequence}));writes.push(()=>tx.create(db.doc(`merchants/${a.merchantId}/branches/${a.branchId}/stockChanges/${String(sequence).padStart(10,'0')}`),{sequence,operationId,kind:'receiving',positions:changes}));
        }
        patch.receiptStatus=discrepancy?'needsReview':'confirmed';patch.receivedLines=accepted;patch.receivedAt=now;patch.receiptReference=operationId;
      }
      status=patch.status??patch.receiptStatus??'recorded';writes.push(()=>tx.update(ref,patch));
    } else if(action==='createRun') {
      const warehouseId=requireDocumentId(input.warehouseId,'warehouse ID');await warehouseRole(warehouseId);
      const driverId=requireDocumentId(input.driverId,'rider');const member=await activeRider(db,tx,a.companyId,driverId,warehouseId);
      if(!Array.isArray(input.orderIds)||!input.orderIds.length||input.orderIds.length>20||new Set(input.orderIds).size!==input.orderIds.length)fail('Choose 1–20 packed orders');
      targetId=`run-${operationId}`;const stops:Data[]=[];
      for(const id of input.orderIds) {const ref=db.doc(`${root}/orders/${requireDocumentId(id,'order ID')}`);const o=(await tx.get(ref)).data() ?? fail('Order unavailable');if(o.warehouseId!==warehouseId||o.status!=='packed'||o.runId)fail('A selected order is no longer available for dispatch');
        stops.push({id:o.id,orderId:o.id,deliveryRunId:targetId,sequence:stops.length+1,destinationId:o.branchId,destinationName:o.storeName,destinationAddress:o.address,contactPerson:o.contact,contactPhone:o.phone,status:'pending',packageManifestId:o.packageReference,
          paymentMethod:o.paymentMethod??'cashOnDelivery',items:o.lines.map((l:Data)=>({productId:l.productId,productName:l.name,sku:l.sku,unitName:l.unit,quantityOrdered:l.quantity,quantityDelivered:0,quantityReturned:0,unitCostCentavos:l.priceCentavos})),amountDueCentavos:o.lines.reduce((s:number,l:Data)=>s+l.quantity*l.priceCentavos,0)-(o.paymentConfirmedCentavos??0)});
        writes.push(()=>tx.update(ref,{runId:targetId,revision:o.revision+1,updatedAt:now}));
      }
      writes.push(()=>tx.create(db.doc(`${root}/deliveryRuns/${targetId}`),{id:targetId,companyId:a.companyId,warehouseId,driverId,driverName:member.get('verifiedEmail')??text(input.driverName,120),vehicleInfo:text(input.vehicleInfo,120),status:'draft',revision:1,createdAt:now,stops,remittanceStatus:'awaitingCollection'}));status='draft';
    } else if(['dispatchRun','cancelRun','recordProof','receiveReturns','confirmRemittance','resolveReceipt','resolveReturns'].includes(action)) {
      targetId=requireDocumentId(input.runId,'run ID');const ref=db.doc(`${root}/deliveryRuns/${targetId}`);const run=(await tx.get(ref)).data();if(!run)fail('Run unavailable');
      if(action==='recordProof') {if(a.role!=='rider'||run!.driverId!==a.uid)deny();await a.policy.requireCompanyRole(request,a.companyId,'rider',run!.warehouseId);}
      else await warehouseRole(run!.warehouseId);
      if(integer(input.expectedRevision)!==run!.revision)fail('Delivery changed. Refresh before continuing.');
      const patch:Data={revision:run!.revision+1};
      if(action==='dispatchRun') {
        if(run!.status!=='draft')fail('Run is already dispatched');
        await activeRider(db,tx,a.companyId,run!.driverId,run!.warehouseId);
        const quantities=new Map<string,number>();
        for(const stop of run!.stops) {const orderRef=db.doc(`${root}/orders/${stop.orderId}`);const order=(await tx.get(orderRef)).data() ?? fail('Order unavailable');if(order.runId!==targetId||order.status!=='packed')fail('Packed order changed');for(const l of order.lines)quantities.set(l.productId,(quantities.get(l.productId)??0)+l.quantity);writes.push(()=>tx.update(orderRef,{status:'dispatched',revision:order.revision+1,updatedAt:now}));}
        for(const [productId,quantity] of quantities)await stockChange(run!.warehouseId,productId,-quantity,-quantity,0,quantity);
        patch.status='dispatched';patch.startedAt=now;
      } else if(action==='cancelRun') {
        if(run!.status!=='draft')fail('Only an undispatched run can be cancelled');text(input.reason);for(const stop of run!.stops){const orderRef=db.doc(`${root}/orders/${stop.orderId}`);const o=(await tx.get(orderRef)).data() ?? fail('Order unavailable');if(o.runId!==targetId)fail('Order assignment changed');writes.push(()=>tx.update(orderRef,{runId:null,revision:o.revision+1,updatedAt:now}));}patch.status='cancelled';patch.reason=input.reason;
      } else if(action==='recordProof') {
        if(!['dispatched','inTransit'].includes(run!.status))fail('Run is not active');const stopId=requireDocumentId(input.stopId,'stop ID');const index=run!.stops.findIndex((s:Data)=>s.id===stopId);if(index<0)deny();const stop=run!.stops[index];if(stop.proof)fail('Proof already recorded');
        const updated=lines(input.items);if(updated.length!==stop.items.length)fail('Record every packed item');
        const items=stop.items.map((l:Data)=>{const i=updated.find(x=>x.productId===l.productId);if(!i)fail('Packed item changed');deliveryQuantities(l.quantityOrdered,i!.quantityDelivered,i!.quantityReturned);if(i!.quantityReturned>0)text(i!.returnReason);return{...l,quantityDelivered:i!.quantityDelivered,quantityReturned:i!.quantityReturned,returnReason:i!.returnReason??null};});
        const deliveredValue=items.reduce((s:number,l:Data)=>s+l.quantityDelivered*l.unitCostCentavos,0);const orderRef=db.doc(`${root}/orders/${stop.orderId}`);const order=(await tx.get(orderRef)).data();if(!order||order.runId!==targetId)deny();
        for(const item of items)if(item.quantityDelivered>0)await stockChange(run!.warehouseId,item.productId,0,0,0,-item.quantityDelivered);
        const cash=integer(input.cashCollectedCentavos);if(order!.paymentMethod==='qr'&&cash>0)fail('This order uses QR payment. Do not collect cash.');if(cash>Math.max(0,deliveredValue-(order!.paymentConfirmedCentavos??0)))fail('Cash exceeds delivered balance');
        const proof={id:operationId,stopId,recipientName:text(input.recipientName,120),recipientRole:text(input.recipientRole,60),cashCollectedCentavos:cash,deliveredAt:now,notes:typeof input.notes==='string'?input.notes.slice(0,200):''};
        const returned=items.reduce((s:number,l:Data)=>s+l.quantityReturned,0);const stopStatus=returned===0?'delivered':items.every((l:Data)=>l.quantityDelivered===0)?'failed':'partiallyDelivered';
        const stops=run!.stops.map((s:Data,i:number)=>i===index?{...s,status:stopStatus,items,proof,returnsStatus:returned>0?'awaitingReceipt':'none'}:s);
        patch.stops=stops;patch.status=stops.every((s:Data)=>s.proof)?'completed':'inTransit';if(patch.status==='completed')patch.completedAt=now;
        writes.push(()=>tx.update(orderRef,{deliveryEvidence:{items,proof,status:stopStatus},revision:order!.revision+1,updatedAt:now}));
        writes.push(()=>tx.create(db.doc(`${root}/collectionEvents/${operationId}`),{runId:targetId,orderId:stop.orderId,driverId:a.uid,amountCentavos:cash,deliveredValueCentavos:deliveredValue,occurredAt:now}));
      } else if(action==='receiveReturns') {
        const stopId=requireDocumentId(input.stopId,'stop ID');const index=run!.stops.findIndex((s:Data)=>s.id===stopId);if(index<0)deny();const stop=run!.stops[index];if(stop.returnsStatus!=='awaitingReceipt')fail('Returns are already received or not due');text(input.reference);
        const returned=lines(input.items);let difference=false;const received:Data[]=[];for(const l of stop.items){if(l.quantityReturned<=0)continue;const item=returned.find(i=>i.productId===l.productId);if(!item)fail('Confirm each returned item');const quantity=integer(item!.quantity,0,l.quantityReturned);if(quantity!==l.quantityReturned)difference=true;received.push({productId:l.productId,quantity});if(quantity>0)await stockChange(run!.warehouseId,l.productId,0,0,quantity,-quantity);}if(difference)text(input.reason);
        patch.stops=run!.stops.map((s:Data,i:number)=>i===index?{...s,returnsStatus:difference?'needsReview':'quarantined',receivedReturns:received,returnReceiptReference:input.reference,returnDifferenceReason:input.reason??''}:s);
      } else if(action==='confirmRemittance') {
        if(run!.status!=='completed')fail('Complete the run before remittance');if(!['awaitingCollection','needsReview'].includes(run!.remittanceStatus))fail('Remittance already recorded');
        const expected=run!.stops.reduce((s:number,stop:Data)=>s+(stop.proof?.cashCollectedCentavos??0),0);const installment=integer(input.amountCentavos);const received=integer(installment+(run!.cashReceivedCentavos??0));if(received!==expected)text(input.reason);
        patch.remittanceStatus=received===expected?'confirmed':'needsReview';patch.cashReceivedCentavos=received;patch.cashExpectedCentavos=expected;patch.remittanceReason=input.reason??'';
        writes.push(()=>tx.create(db.doc(`${root}/remittanceEvents/${operationId}`),{runId:targetId,expectedCentavos:expected,receivedCentavos:installment,totalReceivedCentavos:received,actorId:a.uid,occurredAt:now,reason:input.reason??''}));
      } else if(action==='resolveReturns') {
        const stopId=requireDocumentId(input.stopId,'stop ID');const index=run!.stops.findIndex((s:Data)=>s.id===stopId);if(index<0||run!.stops[index].returnsStatus!=='needsReview')fail('No return discrepancy to resolve');text(input.reason);patch.stops=run!.stops.map((s:Data,i:number)=>i===index?{...s,returnsStatus:'resolved',returnResolution:input.reason}:s);
      } else if(action==='resolveReceipt') {
        const orderId=requireDocumentId(input.orderId,'order ID');const orderRef=db.doc(`${root}/orders/${orderId}`);const order=(await tx.get(orderRef)).data() ?? fail('Order unavailable');if(order.runId!==targetId||order?.receiptStatus!=='needsReview')fail('No receipt discrepancy to resolve');text(input.reason);
        writes.push(()=>tx.update(orderRef,{receiptStatus:'resolved',resolutionNote:input.reason,revision:order!.revision+1,updatedAt:now}));
      }
      status=patch.status??patch.remittanceStatus??'recorded';writes.push(()=>tx.update(ref,patch));
    } else throw new HttpsError('invalid-argument','Unknown company action');
    const result={authorizationVersion:1,companyId:a.companyId,operationId,targetId,status};
    for(const write of writes)write();
    tx.create(receipt,{fingerprint:hash,result,actorId:a.uid,createdAt:FieldValue.serverTimestamp()});
    tx.create(db.doc(`${root}/auditEvents/${operationId}`),{authorizationVersion:1,context:input.context,actorType:'human',actorId:a.uid,action,targetId,operationId,outcome:'accepted',createdAt:FieldValue.serverTimestamp()});
    return result;
  });
}
