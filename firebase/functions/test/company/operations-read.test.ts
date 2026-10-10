import { describe, expect, it } from 'vitest';
import { readCompanyOperations } from '../../src/company/operations-service';

class ReadFixture {
  data = new Map<string, any>();
  reads = new Map<string, number>();
  batches = 0;
  doc(path: string): any {
    return { path, id: path.split('/').at(-1), collection: (name: string) => this.collection(`${path}/${name}`) };
  }
  collection(path: string): any {
    const query: any = { path, clauses: [], cap: 1000, after: '' };
    query.where = (field: string, _op: string, value: unknown) => { query.clauses.push([field, value]); return query; };
    query.orderBy = () => query;
    query.limit = (n: number) => { query.cap = n; return query; };
    query.startAfter = (id: string) => { query.after = id; return query; };
    query.doc = (id: string) => this.doc(`${path}/${id}`);
    return query;
  }
  snapshot(ref: any) {
    this.reads.set(ref.path, (this.reads.get(ref.path) ?? 0) + 1);
    const data = this.data.get(ref.path);
    return { ...ref, ref, exists: data !== undefined, data: () => data,
      get: (key: string) => key.split('.').reduce((v, k) => v?.[k], data) };
  }
  async runTransaction(work: any) {
    return work({ get: async (ref: any) => {
      if (!ref.clauses) return this.snapshot(ref);
      const docs = [...this.data.keys()].filter(path => path.startsWith(`${ref.path}/`) &&
        path.split('/').length === ref.path.split('/').length + 1)
        .sort().filter(path => path.split('/').at(-1)! > ref.after)
        .map(path => this.doc(path)).filter(refDoc => ref.clauses.every(([field,value]: any[]) =>
          field.split('.').reduce((v: any,k: string) => v?.[k], this.data.get(refDoc.path)) === value))
        .slice(0,ref.cap).map(refDoc => this.snapshot(refDoc));
      return { docs, size: docs.length };
    }, getAll: async (...refs: any[]) => { this.batches++; return refs.map(ref => this.snapshot(ref)); } });
  }
}
const identity = { auth: { uid: 'owner', token: { email: 'owner@example.test', email_verified: true,
  firebase: { sign_in_provider: 'google.com' } } } };
function fixture() {
  const f = new ReadFixture();
  for (const [path, data] of Object.entries({
    'companies/c': { companyId: 'c', status: 'active', authorizationVersion: 1 },
    'companies/c/memberships/owner': { companyId: 'c', userId: 'owner', status: 'active', revision: 1 },
    'companies/c/memberships/owner/roles/companyOwner': { companyId: 'c', userId: 'owner', role: 'companyOwner', status: 'active', revision: 1, scope: { kind: 'company' } },
    'companies/c/warehouses/w': { companyId: 'c', warehouseId: 'w', status: 'active' },
    'companies/c/products/a': { name: 'A' }, 'companies/c/products/b': { name: 'B' },
    'companies/c/warehouses/w/stock/a': { physical: 10, reserved: 2 },
  })) f.data.set(path,data);
  const read = (kind: string) => readCompanyOperations(f as any, identity, {
    authorizationVersion: 1, companyId: 'c', context: { kind: 'company', companyId: 'c', role: 'companyOwner' }, warehouseId: 'w', kind });
  return { f, read };
}
describe('bounded company read performance without weaker authorization', () => {
  it('batches product stock and reads authority once per transaction attempt', async () => {
    const { f, read } = fixture();
    const result = await read('products');
    expect(result.records.map((r: any) => r.warehouseStock.physical)).toEqual([10, 0]);
    expect(f.batches).toBe(1);
    expect(f.reads.get('companies/c')).toBe(1);
    expect(f.reads.get('companies/c/warehouses/w')).toBe(1);
    expect(result.source).toBe('server');
  });
  it('next command rechecks revocation instead of reusing authority', async () => {
    const { f, read } = fixture();
    await read('products');
    f.data.get('companies/c/memberships/owner/roles/companyOwner').status = 'removed';
    await expect(read('products')).rejects.toMatchObject({ code: 'permission-denied' });
    expect(f.reads.get('companies/c')).toBe(2);
    expect(f.batches).toBe(1);
  });
  it('denies a warehouse belonging to another company before reading products', async () => {
    const { f, read } = fixture();
    f.data.get('companies/c/warehouses/w').companyId = 'other';
    await expect(read('products')).rejects.toMatchObject({ code: 'permission-denied' });
    expect(f.batches).toBe(0);
  });
});

describe('store catalog projection and branch isolation',()=>{
  function storeFixture(){const {f}=fixture();f.data.set('merchants/m',{status:'active'});f.data.set('merchants/m/memberships/owner',{merchantId:'m',userId:'owner',status:'active',role:'owner',allBranches:true,branchIds:[]});f.data.set('merchants/m/branches/b',{merchantId:'m',status:'active',address:'Branch address',contactDetails:{phone:'123',name:'Owner'}});
    const read=(kind:string,values:any={})=>readCompanyOperations(f as any,identity,{authorizationVersion:1,companyId:'c',context:{kind:'store',merchantId:'m',branchId:'b'},warehouseId:'w',kind,...values});return{f,read};}
  it('search cursor reaches later products; batches availability without leaking stock/cost',async()=>{
    const{f,read}=storeFixture();f.data.delete('companies/c/products/a');f.data.delete('companies/c/products/b');
    for(let i=0;i<60;i++)f.data.set(`companies/c/products/p${String(i).padStart(3,'0')}`,{name:i===59?'Wanted Milk':'Other',sku:`SKU${i}`,unit:'can',active:true,priceCentavos:500,revision:1,purchaseCost:100});
    let cursor:any;const found:any[]=[];let pages=0;do{const page=await read('catalog',{search:'wanted',...(cursor?{cursor}:{})});found.push(...page.records);cursor=page.nextCursor;pages++;}while(cursor);
    expect(pages).toBe(3);expect(found).toHaveLength(1);expect(found[0]).toMatchObject({id:'p059',availability:'outOfStock'});
    expect(found[0]).not.toHaveProperty('purchaseCost');expect(found[0]).not.toHaveProperty('warehouseStock');
    const selected=await read('selectedProducts',{productIds:['p059']});expect(selected.records).toHaveLength(1);
  });
  it('preferences use branch defaults and reject another branch and company roles',async()=>{
    const{f,read}=storeFixture();const prefs=await read('orderingPreferences');expect(prefs.records[0]).toMatchObject({address:'Branch address',phone:'123',contact:'Owner'});
    await expect(read('orderingPreferences',{context:{kind:'store',merchantId:'m',branchId:'other'}})).rejects.toMatchObject({code:'permission-denied'});
    await expect(read('productMappings',{context:{kind:'company',companyId:'c',role:'companyOwner'}})).rejects.toMatchObject({code:'permission-denied'});
    f.data.get('merchants/m/memberships/owner').status='removed';await expect(read('catalog')).rejects.toMatchObject({code:'permission-denied'});
  });
});
