#!/usr/bin/env node
'use strict';

// Trusted operator utility. Never expose as a client command or run in Production.
// Builds a private, immutable plan before writing. Reuse its state directory to
// replay the same service operation IDs without adding opening stock twice.
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { saveCatalogProduct, recordStockCount } = require('../lib/catalog/catalog-service');
const { mutateCompanyOperations } = require('../lib/company/operations-service');
const { AuthorizationService } = require('../lib/common/authz');
const fixture = require('./presentation-products.json');
const projectId = 'sarisupply-dev-aracena18';
const merchantId = 'beta-store';
const branchId = 'main-branch';
const companyId = 'sarisupply';
const seedId = 'presentation-20261007-v1';
const repo = path.resolve(__dirname, '../../..');
const hash = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const arg = name => {
  const index = process.argv.indexOf(name);
  if (index < 0 || !process.argv[index + 1] || process.argv[index + 1].startsWith('--')) {
    throw new Error(`Required: ${name}`);
  }
  return path.resolve(process.argv[index + 1]);
};
const outsideRepo = file => {
  const relative = path.relative(repo, file);
  if (!relative.startsWith('..') && !path.isAbsolute(relative)) {
    throw new Error('Credentials and private seed state must stay outside the repository');
  }
};
const ean = number => {
  const digits = `200${String(number).padStart(9, '0')}`;
  const sum = [...digits].reduce((total, digit, i) => total + Number(digit) * (i % 2 ? 3 : 1), 0);
  return digits + ((10 - sum % 10) % 10);
};
const serialQueue = () => {
  let pending = Promise.resolve();
  return task => {
    const result = pending.then(task);
    // Reset the queue after failure; callers still await the rejecting result.
    pending = result.catch(() => {});
    return result;
  };
};
const snapshot = async (db, collection) => (await db.collection(collection).get()).docs
  .map(doc => ({ ...doc.data(), id: doc.id }));
const photoFor = product => {
  const extra = fixture.products.find(p => p.sku === product.sku);
  if (extra) return fixture.photos[extra.photo];
  const name = product.name.toLowerCase();
  const category = /laptop/.test(name) ? 'laptop'
    : /water/.test(name) ? 'water'
    : /chocolate|wafer/.test(name) ? 'chocolate'
    : /milk/.test(name) ? 'milk'
    : /sardine|corned|luncheon|tuna|mackerel|tomato sauce|beans/.test(name) ? 'canned'
    : /cola|soda/.test(name) ? 'cola'
    : /juice|tea|energy/.test(name) ? 'juice'
    : /noodle|pancit/.test(name) ? 'noodles'
    : /coffee|kopi|koko/.test(name) ? 'coffee'
    : /rice/.test(name) ? 'rice'
    : /bread|jam|peanut/.test(name) ? 'bread'
    : /soap|shampoo|tooth|tissue|detergent|dishwash|fabric|pads/.test(name) ? 'personal'
    : /oil|sauce|vinegar|ketchup/.test(name) ? 'oil'
    : /sugar|salt|season|pepper/.test(name) ? 'pantry' : 'snacks';
  return fixture.photos[category];
};

async function identity(auth, uid, company = false) {
  const user = await auth.getUser(uid);
  if (user.disabled) throw new Error('A business Owner account is disabled');
  if (company && (!user.emailVerified || !user.providerData.some(p => p.providerId === 'google.com'))) {
    throw new Error('Company Owner must be a verified Google identity');
  }
  // Derived from the trusted Auth record, never from unverified client claims.
  return { auth: { uid, token: { email: user.email, email_verified: user.emailVerified,
    firebase: { sign_in_provider: company ? 'google.com' : user.providerData[0]?.providerId } } } };
}

async function main() {
  const credentialsPath = arg('--service-account');
  const stateDir = arg('--state-dir');
  outsideRepo(credentialsPath); outsideRepo(stateDir);
  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf8'));
  if (credentials.type !== 'service_account' || credentials.project_id !== projectId ||
      process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Only the selected live Development project is supported');
  const app = initializeApp({ credential: cert(credentials), projectId });
  const db = getFirestore(app); const auth = getAuth(app);
  const store = await db.doc(`merchants/${merchantId}`).get();
  const branch = await db.doc(`merchants/${merchantId}/branches/${branchId}`).get();
  const company = await db.doc(`companies/${companyId}`).get();
  if (store.get('status') !== 'active' || store.get('beta') !== true || branch.get('status') !== 'active' ||
      branch.get('merchantId') !== merchantId || company.get('status') !== 'active') {
    throw new Error('Development presentation scope is not active');
  }
  const owners = (await snapshot(db, `merchants/${merchantId}/memberships`))
    .filter(m => m.role === 'owner' && m.status === 'active' && m.allBranches === true);
  const warehouses = (await snapshot(db, `companies/${companyId}/warehouses`)).filter(w => w.status === 'active');
  if (owners.length !== 1 || warehouses.length !== 1) throw new Error('Expected exactly one Store Owner and active warehouse');
  const warehouseId = warehouses[0].id;
  const retailRequest = await identity(auth, owners[0].userId);
  const companyRequest = await identity(auth, company.get('ownerUid'), true);
  const policy = new AuthorizationService(async p => (await db.doc(p).get()).data() ?? null);
  await policy.requireOwner(retailRequest.auth.uid, merchantId);
  await policy.requireBranchAccess(retailRequest.auth.uid, merchantId, branchId);
  await policy.requireCompanyRole(companyRequest, companyId, 'companyOwner', warehouseId);
  const companyContext = { kind: 'company', companyId, role: 'companyOwner' };
  const storeContext = { kind: 'store', merchantId, branchId };
  const companyBase = { authorizationVersion: 1, companyId, context: companyContext };
  const orderingRoot = `merchants/${merchantId}/branches/${branchId}/companyOrdering/${companyId}`;
  const planFile = path.join(stateDir, 'plan.json');
  let plan;
  if (fs.existsSync(planFile)) {
    plan = JSON.parse(fs.readFileSync(planFile, 'utf8'));
    if (plan.projectId !== projectId || plan.seedId !== seedId || plan.warehouseId !== warehouseId ||
        plan.storeOwner !== retailRequest.auth.uid || plan.companyOwner !== companyRequest.auth.uid ||
        plan.fixtureHash !== hash(fixture)) throw new Error('Saved plan scope or fixture changed');
  } else {
    const collections = [
      `merchants/${merchantId}/products`, `merchants/${merchantId}/inventoryMeta`,
      `merchants/${merchantId}/skuRegistry`, `merchants/${merchantId}/barcodeRegistry`,
      `merchants/${merchantId}/branches/${branchId}/stock`,
      `merchants/${merchantId}/branches/${branchId}/inventoryMeta`,
      `companies/${companyId}/products`, `companies/${companyId}/skuRegistry`,
      `companies/${companyId}/warehouses/${warehouseId}/stock`, `${orderingRoot}/productMappings`,
    ];
    const before = {};
    for (const collection of collections) before[collection] = await snapshot(db, collection);
    const retail = before[collections[0]].filter(p => p.active === true);
    const wholesale = before[`companies/${companyId}/products`].filter(p => p.active === true);
    const additional = fixture.products;
    for (const p of additional) if (!retail.some(r => r.sku === p.sku)) retail.push({
      id: p.id, sku: p.sku, name: p.name, baseUnit: 'piece', active: true, revision: 0,
      units: [{ name:'piece', factor:1, priceCentavos:p.retail, barcode:'' },
        { name:'pack-6', factor:6, priceCentavos:p.retail * 6 - 300, barcode:'' }],
    });
    for (const p of wholesale) if (!retail.some(r => r.sku.toUpperCase() === p.sku.toUpperCase())) retail.push({
      id:`presentation-company-${p.id}`, sku:p.sku.toUpperCase(), name:p.name,
      baseUnit:p.unit, active:true, revision:0,
      units:[{name:p.unit,factor:1,priceCentavos:Math.max(100,Math.ceil(p.priceCentavos * 1.2 / 50) * 50),barcode:''}],
    });
    retail.sort((a,b) => a.id.localeCompare(b.id));
    const pairs = []; let serial = 1;
    for (const [index, p] of retail.entries()) {
      const c = wholesale.find(w => w.sku.toUpperCase() === p.sku.toUpperCase());
      if (c && (c.name !== p.name || c.unit !== p.baseUnit)) throw new Error(`Ambiguous existing SKU ${p.sku}`);
      const extra = additional.find(a => a.sku === p.sku);
      const imageUrl = p.image?.secureUrl || photoFor(p);
      const units = p.units.map(unit => ({...unit, barcode:ean(serial++)}));
      const companyProduct = c || {id:`presentation-store-${p.id}`,revision:0,
        sku:p.sku,name:p.name,unit:p.baseUnit,
        priceCentavos:extra?.wholesale ?? Math.max(100,Math.round(units[0].priceCentavos * .85 / 50) * 50)};
      const storeStock = before[`merchants/${merchantId}/branches/${branchId}/stock`].find(s => s.id === p.id);
      const warehouseStock = before[`companies/${companyId}/warehouses/${warehouseId}/stock`].find(s => s.id === companyProduct.id);
      pairs.push({
        retail: {merchantId,operationId:`${seedId}-retail-${p.id}`,expectedRevision:p.revision,
          product:{id:p.id,sku:p.sku,name:p.name,baseUnit:p.baseUnit,active:true,units,imageUrl},
          imageChange:p.image ? {action:'keep'} : {action:'url',url:imageUrl}},
        company: {...companyBase,action:'saveProduct',operationId:`${seedId}-company-${p.id}`,
          productId:companyProduct.id,expectedRevision:companyProduct.revision,name:companyProduct.name,
          sku:companyProduct.sku,unit:companyProduct.unit,priceCentavos:companyProduct.priceCentavos,imageUrl},
        stock: storeStock ? null : {merchantId,branchId,operationId:`${seedId}-retailstock-${p.id}`,
          productId:p.id,expectedRevision:0,quantity:extra?.storeStock ?? 20 + index % 5 * 5,
          kind:'opening',reason:'Presentation demo opening stock; independent retail inventory'},
        warehouse: warehouseStock ? null : {...companyBase,action:'receiveStock',
          operationId:`${seedId}-warehousestock-${p.id}`,warehouseId,productId:companyProduct.id,
          quantity:extra?.warehouseStock ?? 150 + index % 5 * 60,
          reference:'Presentation demo opening stock; company warehouse inventory'},
        mapping:{authorizationVersion:1,companyId,context:storeContext,action:'saveProductMapping',
          operationId:`${seedId}-mapping-${p.id}`,retailProductId:p.id,productId:companyProduct.id,
          retailUnitsPerCompanyUnit:1},
      });
    }
    if (new Set(pairs.map(p=>p.retail.product.sku)).size !== pairs.length ||
        new Set(pairs.flatMap(p=>p.retail.product.units.map(u=>u.barcode))).size !== serial - 1) {
      throw new Error('Duplicate SKU or barcode in the seed plan');
    }
    fs.mkdirSync(stateDir,{recursive:true,mode:0o700});
    fs.writeFileSync(path.join(stateDir,'before.json'),JSON.stringify(before,null,2),{flag:'wx',mode:0o600});
    plan = {projectId,seedId,warehouseId,storeOwner:retailRequest.auth.uid,
      companyOwner:companyRequest.auth.uid,fixtureHash:hash(fixture),pairs,createdAt:new Date().toISOString()};
    fs.writeFileSync(planFile,JSON.stringify(plan,null,2),{flag:'wx',mode:0o600});
  }
  console.log(JSON.stringify({projectId,merchantId,branchId,companyId,warehouse:warehouses[0].name,
    matchedProducts:plan.pairs.length,newRetailStock:plan.pairs.filter(p=>p.stock).length,
    newWarehouseStock:plan.pairs.filter(p=>p.warehouse).length,apply:process.argv.includes('--apply')}));
  // Validate every unique photo before making any business write.
  for (const url of new Set(plan.pairs.map(p=>p.retail.product.imageUrl))) {
    const response = await fetch(url,{signal:AbortSignal.timeout(30000)});
    if (!response.ok || !response.headers.get('content-type')?.startsWith('image/')) {
      throw new Error(`Unavailable product photo (${response.status}): ${url}`);
    }
    await response.arrayBuffer();
  }
  if (!process.argv.includes('--apply')) {console.log('Dry run complete; private backup and replay plan saved.');return;}
  // Serialize shared retail feed counters. Other product/warehouse/mapping
  // records are independent, so four workers can progress without counter races.
  const saveRetail = serialQueue(); const saveRetailStock = serialQueue();
  let nextPair = 0; let completed = 0; let failed = false;
  await Promise.all(Array.from({length:4},async () => {
   while(!failed && nextPair < plan.pairs.length) {
    const pair = plan.pairs[nextPair++];
    try {
    await saveRetail(() => saveCatalogProduct(db,retailRequest,pair.retail));
    await mutateCompanyOperations(db,companyRequest,pair.company);
    // The company reader already accepts barcode metadata. Seed it as a trusted
    // operator extension without claiming ownership of public external photos.
    const metadataId = `${seedId}-barcode-${pair.retail.product.id}`;
    await db.runTransaction(async tx => {
      const currentPolicy = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
      await currentPolicy.requireCompanyRole(companyRequest,companyId,'companyOwner',warehouseId);
      const receipt = db.doc(`companies/${companyId}/presentationSeedOperations/${metadataId}`);
      const product = db.doc(`companies/${companyId}/products/${pair.company.productId}`);
      const old = await tx.get(receipt); const saved = await tx.get(product);
      const barcodes = pair.retail.product.units.map(u=>u.barcode);
      if (old.exists) {if(old.get('fingerprint')!==hash(barcodes))throw new Error('Barcode seed receipt conflict');return;}
      if(saved.get('sku')!==pair.company.sku||saved.get('unit')!==pair.company.unit)throw new Error('Company product changed');
      tx.update(product,{barcode:barcodes[0],barcodes,revision:saved.get('revision')+1,
        barcodePurpose:fixture.barcodePurpose});
      tx.create(receipt,{fingerprint:hash(barcodes),seedId,productId:product.id,
        provisioningAuthority:'trustedAdminSdk',actorId:companyRequest.auth.uid,createdAt:FieldValue.serverTimestamp()});
      tx.create(db.doc(`companies/${companyId}/auditEvents/${metadataId}`),{action:'seedPresentationBarcodes',
        seedId,targetId:product.id,actorId:companyRequest.auth.uid,provisioningAuthority:'trustedAdminSdk',
        operationId:metadataId,createdAt:FieldValue.serverTimestamp()});
    });
    if(pair.stock){const result=await saveRetailStock(() => recordStockCount(db,retailRequest,pair.stock));
      if(!['accepted','duplicate'].includes(result.status))throw new Error(`Opening stock ${result.status}: ${pair.stock.productId}`);}
    if(pair.warehouse)await mutateCompanyOperations(db,companyRequest,pair.warehouse);
    await mutateCompanyOperations(db,retailRequest,pair.mapping);
    completed++;
    if(completed%5===0||completed===plan.pairs.length)console.log(`Seeded ${completed}/${plan.pairs.length} matched products`);
    } catch(error) {failed = true; throw error;}
   }
  }));
  const retail = await snapshot(db,`merchants/${merchantId}/products`);
  const wholesale = await snapshot(db,`companies/${companyId}/products`);
  const retailStocks = await snapshot(db,`merchants/${merchantId}/branches/${branchId}/stock`);
  const warehouseStocks = await snapshot(db,`companies/${companyId}/warehouses/${warehouseId}/stock`);
  const mappings = await snapshot(db,`${orderingRoot}/productMappings`);
  for(const pair of plan.pairs){
    const r=retail.find(p=>p.id===pair.retail.product.id),c=wholesale.find(p=>p.id===pair.company.productId);
    const mapping=mappings.find(m=>m.id===r?.id);
    if(!r||!c||r.name!==c.name||r.baseUnit!==c.unit||r.units[0].barcode!==c.barcode||
       r.imageUrl!==c.imageUrl||!retailStocks.some(s=>s.id===r.id)||!warehouseStocks.some(s=>s.id===c.id)||
       mapping?.productId!==c.id||mapping.retailUnitsPerCompanyUnit!==1)throw new Error('Catalog/stock/mapping verification failed');
  }
  const before=JSON.parse(fs.readFileSync(path.join(stateDir,'before.json'),'utf8'));
  for(const [collection,current,fields] of [
    [`merchants/${merchantId}/branches/${branchId}/stock`,retailStocks,['quantity','revision']],
    [`companies/${companyId}/warehouses/${warehouseId}/stock`,warehouseStocks,['physical','reserved','quarantined','inTransit','revision']],
  ])for(const old of before[collection]){const live=current.find(s=>s.id===old.id);
    if(!live||fields.some(f=>live[f]!==old[f]))throw new Error('An existing stock balance changed during seeding; inspect concurrent activity');}
  if(retail.filter(p=>p.active).length!==plan.pairs.length||wholesale.filter(p=>p.active).length!==plan.pairs.length) {
    throw new Error('Active catalog counts differ; inspect concurrent products');
  }
  const report={seedId,projectId,matchedProducts:plan.pairs.length,barcodes:'internal EAN-13 demo numbers',
    photos:fixture.photoPurpose,existingStockPreserved:true,verifiedAt:new Date().toISOString()};
  await db.runTransaction(async tx=>{
    for(const root of [`merchants/${merchantId}`,`companies/${companyId}`]){
      tx.set(db.doc(`${root}/presentationSeedRuns/${seedId}`),{...report,
        provisioningAuthority:'trustedAdminSdk',operatorServiceAccount:credentials.client_email});
    }
  });
  fs.writeFileSync(path.join(stateDir,'result.json'),JSON.stringify(report,null,2),{mode:0o600});
  console.log(JSON.stringify(report));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
