import { describe, expect, it } from 'vitest';
import { mutateCompanyOperations, stockReservation, deliveryQuantities } from '../../src/company/operations-service';

// A transactional in-memory fixture exercises business transitions without live identities.
class Fixture {
  data = new Map<string, any>();
  doc(path: string) { return { path, id: path.split('/').at(-1) }; }
  async runTransaction(work: any) {
    const next = new Map(this.data);
    const snapshot=(ref:any)=>({id:ref.id,exists:next.has(ref.path),data:()=>next.get(ref.path),get:(key:string)=>key.split('.').reduce((v,k)=>v?.[k],next.get(ref.path))});
    const tx = {
      getAll: async (...refs:any[])=>refs.map(snapshot),
      get: async (ref: any) => ({ id:ref.id, exists:next.has(ref.path),data:()=>next.get(ref.path),get:(key:string)=>key.split('.').reduce((v,k)=>v?.[k],next.get(ref.path)) }),
      create: (ref:any, data:any) => {if(next.has(ref.path))throw Error('Document exists');next.set(ref.path,structuredClone(data));},
      set:(ref:any,data:any)=>next.set(ref.path,structuredClone(data)),
      update:(ref:any,data:any)=>next.set(ref.path,{...next.get(ref.path),...structuredClone(data)}),
    };
    const result=await work(tx);this.data=next;return result;
  }
}
const identity=(uid:string)=>({auth:{uid,token:{email:`${uid}@example.test`,email_verified:true,firebase:{sign_in_provider:'google.com'}}}});
function fixture() {
  const f=new Fixture();
  for(const [path,data] of Object.entries({
    'companies/c':{companyId:'c',status:'active',authorizationVersion:1,paymentInstructions:'Pay to SariSupply QR account.'},
    'companies/c/warehouses/w':{companyId:'c',warehouseId:'w',status:'active'},
    'companies/c/memberships/owner':{companyId:'c',userId:'owner',status:'active',revision:1},
    'companies/c/memberships/owner/roles/companyOwner':{companyId:'c',userId:'owner',status:'active',revision:1,role:'companyOwner',scope:{kind:'company'}},
    'companies/c/memberships/ops':{companyId:'c',userId:'ops',status:'active',revision:1},
    'companies/c/memberships/ops/roles/warehouseOperations':{companyId:'c',userId:'ops',status:'active',revision:1,role:'warehouseOperations',scope:{kind:'warehouses',warehouseIds:['w']}},
    'companies/c/memberships/rider':{companyId:'c',userId:'rider',status:'active',revision:1},
    'companies/c/memberships/rider/roles/rider':{companyId:'c',userId:'rider',status:'active',revision:1,role:'rider',scope:{kind:'warehouses',warehouseIds:['w']}},
    'merchants/m':{status:'active',name:'Store'},
    'merchants/m/memberships/store':{merchantId:'m',userId:'store',status:'active',role:'owner',allBranches:true,branchIds:[]},
    'merchants/m/branches/b':{merchantId:'m',status:'active',name:'Branch'},
    'merchants/m/products/retail':{active:true},
  })) f.data.set(path,data);
  let sequence=0;
  const call=(uid:string,role:string,action:string,values:any,operationId?:string)=>mutateCompanyOperations(f as any,identity(uid),{
    authorizationVersion:1,companyId:'c',context:role==='storeOwner'?{kind:'store',merchantId:'m',branchId:'b'}:{kind:'company',companyId:'c',role},action,operationId:operationId??`operation-${++sequence}`,...values,
  });
  return {f,call};
}
describe('Company fulfillment',()=>{
  it('confirms remaining QR amounts once and rejects an extra payment',async()=>{
    const {f,call}=fixture();
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:500,expectedRevision:0});
    await call('owner','companyOwner','receiveStock',{warehouseId:'w',productId:'p',quantity:2,reference:'Opening count'});
    const submitted=await call('store','storeOwner','submitOrder',{warehouseId:'w',paymentMethod:'qr',address:'Address',contact:'Person',phone:'123',lines:[{productId:'p',quantity:1,productRevision:1}]});
    const orderId=submitted.targetId;
    await call('owner','companyOwner','acceptOrder',{orderId,expectedRevision:1});
    await call('owner','companyOwner','confirmQr',{orderId,expectedRevision:2,amountCentavos:200,reference:'Verified partial payment'});
    const remaining={orderId,expectedRevision:3,amountCentavos:300,reference:'Verified remaining payment'};
    await call('owner','companyOwner','confirmQr',remaining,'qr-replay');
    await call('owner','companyOwner','confirmQr',remaining,'qr-replay');
    expect(f.data.get(`companies/c/orders/${orderId}`)).toMatchObject({paymentConfirmedCentavos:500,revision:4,status:'accepted'});
    expect([...f.data.keys()].filter(path=>path.startsWith('companies/c/paymentEvents/'))).toHaveLength(2);
    await expect(call('owner','companyOwner','confirmQr',{orderId,expectedRevision:4,amountCentavos:1,reference:'Additional payment'})).rejects.toMatchObject({code:'failed-precondition',message:'Payment exceeds order value'});
    expect(f.data.get(`companies/c/orders/${orderId}`)).toMatchObject({paymentConfirmedCentavos:500,revision:4});
    expect([...f.data.keys()].filter(path=>path.startsWith('companies/c/paymentEvents/'))).toHaveLength(2);
  });
  it('prevents overselling and requires accounting for every delivered unit',()=>{
    expect(stockReservation(10,4,6)).toBe(10);
    expect(()=>stockReservation(10,4,7)).toThrow();
    expect(()=>stockReservation(10,4,-5)).toThrow();
    expect(()=>deliveryQuantities(10,8,1)).toThrow();
    expect(()=>deliveryQuantities(10,8,2)).not.toThrow();
  });
  it.each([3,0])('keeps stock ownership, receiving, replay and remittance separate (received %i)',async(received)=>{
    const {f,call}=fixture();
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:100,expectedRevision:0});
    await call('owner','companyOwner','receiveStock',{warehouseId:'w',productId:'p',quantity:10,reference:'Opening count'});
    const submitted=await call('store','storeOwner','submitOrder',{warehouseId:'w',address:'Address',contact:'Person',phone:'123',lines:[{productId:'p',quantity:4,productRevision:1}]});
    const orderId=submitted.targetId;
    await call('owner','companyOwner','acceptOrder',{orderId,expectedRevision:1});
    expect(f.data.get('companies/c/warehouses/w/stock/p')).toMatchObject({physical:10,reserved:4});
    await call('owner','companyOwner','startPicking',{orderId,expectedRevision:2});
    await call('owner','companyOwner','packOrder',{orderId,expectedRevision:3,packageReference:'PACK-1',lines:[{productId:'p',quantity:4}]});
    const run=await call('owner','companyOwner','createRun',{warehouseId:'w',driverId:'rider',driverName:'Rider',vehicleInfo:'Van',orderIds:[orderId]});
    await call('owner','companyOwner','dispatchRun',{runId:run.targetId,expectedRevision:1});
    expect(f.data.get('companies/c/warehouses/w/stock/p')).toMatchObject({physical:6,reserved:0});
    const proof={runId:run.targetId,expectedRevision:2,stopId:orderId,recipientName:'Person',recipientRole:'Owner',cashCollectedCentavos:300,items:[{productId:'p',quantityDelivered:3,quantityReturned:1,returnReason:'Damaged'}]};
    await call('rider','rider','recordProof',proof,'proof-replay');
    await call('rider','rider','recordProof',proof,'proof-replay');
    expect(f.data.has('merchants/m/branches/b/stock/retail')).toBe(false);
    const order=f.data.get(`companies/c/orders/${orderId}`);
    const receipt={orderId,expectedRevision:order.revision,lines:[{productId:'p',quantity:received,retailProductId:'retail',retailUnitsPerCompanyUnit:2}]};
    await call('store','storeOwner','confirmReceipt',receipt,'receipt-replay');
    await call('store','storeOwner','confirmReceipt',receipt,'receipt-replay');
    if(received) expect(f.data.get('merchants/m/branches/b/stock/retail')).toEqual({quantity:received*2,revision:1});
    else { expect(f.data.has('merchants/m/branches/b/stock/retail')).toBe(false); expect(f.data.has('merchants/m/branches/b/inventoryMeta/stock')).toBe(false); }
    expect(f.data.get(`companies/c/deliveryRuns/${run.targetId}`).remittanceStatus).toBe('awaitingCollection');
    await call('owner','companyOwner','receiveReturns',{runId:run.targetId,expectedRevision:3,stopId:orderId,reference:'Return',items:[{productId:'p',quantity:1}]});
    expect(f.data.get('companies/c/warehouses/w/stock/p')).toMatchObject({physical:6,quarantined:1});
    await call('owner','companyOwner','confirmRemittance',{runId:run.targetId,expectedRevision:4,amountCentavos:300});
    expect(f.data.get(`companies/c/deliveryRuns/${run.targetId}`).remittanceStatus).toBe('confirmed');
    await expect(call('store','storeOwner','receiveStock',{warehouseId:'w',productId:'p',quantity:1,reference:'Not allowed'})).rejects.toMatchObject({code:'permission-denied'});
    await expect(call('rider','rider','dispatchRun',{runId:run.targetId,expectedRevision:5})).rejects.toMatchObject({code:'permission-denied'});
  });
});

describe('store sourcing and ordering preferences',()=>{
  it('sourcing request replay creates one request, no stock or order; only company operations responds',async()=>{
    const {f,call}=fixture();
    const values={warehouseId:'w',name:'New item',quantity:2,unit:'case',details:'Brand',contact:'Owner',phone:'123'};
    const first=await call('store','storeOwner','submitItemRequest',values,'request-replay');
    await call('store','storeOwner','submitItemRequest',values,'request-replay');
    expect([...f.data.keys()].filter(k=>k.startsWith('companies/c/itemRequests/'))).toHaveLength(1);
    expect([...f.data.keys()].some(k=>k.includes('/stock/')||k.startsWith('companies/c/orders/'))).toBe(false);
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:500,expectedRevision:0});
    const response={requestId:first.targetId,expectedRevision:1,response:'Checking supplier',productId:'p'};
    await expect(call('store','storeOwner','respondItemRequest',response)).rejects.toMatchObject({code:'permission-denied'});
    await expect(call('rider','rider','respondItemRequest',response)).rejects.toMatchObject({code:'permission-denied'});
    await call('owner','companyOwner','respondItemRequest',response,'response-replay');
    await call('owner','companyOwner','respondItemRequest',response,'response-replay');
    expect(f.data.get(`companies/c/itemRequests/${first.targetId}`)).toMatchObject({status:'responded',revision:2});
    await expect(call('owner','companyOwner','closeItemRequest',{...response,expectedRevision:1})).rejects.toMatchObject({code:'failed-precondition'});
    await call('owner','companyOwner','closeItemRequest',{...response,expectedRevision:2});
    expect(f.data.get(`companies/c/itemRequests/${first.targetId}`)).toMatchObject({status:'closed',productId:'p'});
  });
  it('stores explicit mappings only for owner and active retail/company products',async()=>{
    const {f,call}=fixture();
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'case',priceCentavos:500,expectedRevision:0});
    const mapping={retailProductId:'retail',productId:'p',retailUnitsPerCompanyUnit:12};
    await call('store','storeOwner','saveProductMapping',mapping,'mapping-replay');
    await call('store','storeOwner','saveProductMapping',mapping,'mapping-replay');
    expect(f.data.get('merchants/m/branches/b/companyOrdering/c/productMappings/retail')).toMatchObject(mapping);
    await expect(call('owner','companyOwner','saveProductMapping',mapping)).rejects.toMatchObject({code:'permission-denied'});
    await expect(call('store','storeOwner','saveProductMapping',{...mapping,retailUnitsPerCompanyUnit:0})).rejects.toMatchObject({code:'invalid-argument'});
    f.data.get('merchants/m/products/retail').active=false;
    await expect(call('store','storeOwner','saveProductMapping',mapping)).rejects.toMatchObject({code:'failed-precondition'});
  });
  it('snapshots delivery defaults with a backorder without reserving stock',async()=>{
    const {f,call}=fixture();
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:500,expectedRevision:0});
    const order={warehouseId:'w',address:'Saved address',contact:'Owner',phone:'123',lines:[{productId:'p',quantity:1,productRevision:1}]};
    await call('store','storeOwner','submitOrder',order,'backorder-replay');
    await call('store','storeOwner','submitOrder',order,'backorder-replay');
    expect(f.data.get('merchants/m/branches/b/companyOrdering/c')).toEqual({warehouseId:'w',address:'Saved address',contact:'Owner',phone:'123'});
    expect(f.data.has('companies/c/warehouses/w/stock/p')).toBe(false);
    await expect(call('owner','companyOwner','acceptOrder',{orderId:'order-backorder-replay',expectedRevision:1})).rejects.toMatchObject({code:'failed-precondition'});
  });
  it('manages company product photos by URL with owner-only writes',async()=>{
    const {f,call}=fixture();
    const photo='https://images.unsplash.com/photo-1584947920387-9bc683bc4892?auto=format&fit=crop&w=400&q=80';
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:500,expectedRevision:0,imageUrl:photo});
    expect(f.data.get('companies/c/products/p')).toMatchObject({imageUrl:photo,revision:1});
    // Omitted photo preserves; empty clears.
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:600,expectedRevision:1});
    expect(f.data.get('companies/c/products/p')).toMatchObject({imageUrl:photo,revision:2});
    await call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:600,expectedRevision:2,imageUrl:''});
    expect(f.data.get('companies/c/products/p')).not.toHaveProperty('imageUrl');
    await expect(call('owner','companyOwner','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:600,expectedRevision:3,imageUrl:'http://insecure.example/x.png'})).rejects.toMatchObject({code:'invalid-argument'});
    await expect(call('ops','warehouseOperations','saveProduct',{productId:'p',name:'Can',sku:'CAN',unit:'can',priceCentavos:600,expectedRevision:3,imageUrl:photo})).rejects.toMatchObject({code:'permission-denied'});
    expect(f.data.get('companies/c/products/p')).toMatchObject({revision:3});
  });
});
