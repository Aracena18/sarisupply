// Local acceptance probe for the exact runtime advertised by Deno Deploy.
// Never uses hosted credentials or a real Firebase project.
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { generateKeyPairSync } = require('node:crypto');
const { initializeApp, deleteApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getAppCheck } = require('firebase-admin/app-check');
const { initializeFirestore } = require('firebase-admin/firestore');
const { OAuth2Client } = require('google-auth-library');
const { createPinHasher } = require('../../lib/cashier/pin-kdf.js');
const { createCommandDispatcher } = require('../../lib/https/commands.js');
const { createHttpsHandler } = require('../../lib/https/handler.js');
const { createGatewayServer } = require('../../lib/https/server.js');

async function probe() {
  let stage = 'startup';
  const deadline = setTimeout(() => {
    console.error(`Deno runtime probe timed out at ${stage}`);
    process.exit(1);
  }, 45_000);
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
    assert.match(process.env[key] ?? '', /^(127\.0\.0\.1|localhost):\d+$/, 'Local emulators required');
  }
  assert.equal(Deno.version.deno, '2.5.0');
  const cpuStart = process.cpuUsage();
  const started = performance.now();
  const hasher = createPinHasher('test-only-server-pepper-12345678901234567890');
  stage = 'scrypt';
  // Filled with a reference generated independently under Node 22.
  const stored = { salt: Buffer.alloc(16).toString('base64'), hash: 'hidUjX9pAUEaL5H1OGXjDJpGiR/EdnBXK/GSF2y9ykQ=' };
  assert.equal(await hasher.verify('483920', stored), true);
  assert.equal(await hasher.verify('483921', stored), false);
  assert.equal(await hasher.verify('483920', await hasher.hash('483920')), true);

  const projectId = 'demo-sarisupply-rules';
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048,
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    publicKeyEncoding: { type: 'spki', format: 'pem' } });
  // Ephemeral fixture certificate matches hosted credential initialization
  // without ADC/metadata lookup; it is never sent
  // to a hosted API and is not retained on disk.
  const app = initializeApp({ projectId, credential: cert({ projectId,
    clientEmail: 'runtime-fixture@demo-sarisupply-rules.iam.gserviceaccount.com', privateKey }) }, 'deno-runtime-probe');
  const auth = getAuth(app);
  const db = initializeFirestore(app, { preferRest: true });
  // Google's REST transport authenticates through an AuthClient even on the
  // emulator. Supply its documented admin token only after loopback guards.
  // The hosted entrypoint uses cert credentials and has no emulator AuthClient.
  const emulatorAuth = new OAuth2Client();
  emulatorAuth.setCredentials({ access_token: 'owner', expiry_date: Date.now() + 3600_000 });
  db.settings({ authClient: emulatorAuth });
  const merchantId = 'deno-runtime-merchant';
  const branchId = 'deno-runtime-branch';
  const deviceId = 'deno-runtime-device';
  const paths = [`merchants/${merchantId}`, `merchants/${merchantId}/branches/${branchId}`,
    `merchants/${merchantId}/devices/${deviceId}`];
  let server;
  let report;
  try {
    stage = 'App Check validation';
    await assert.rejects(getAppCheck(app).verifyToken('not-a-token'),
      (error) => error.code === 'app-check/invalid-argument');
    stage = 'Firestore write transaction';
    console.log(`Runtime probe: ${stage}`);
    await db.runTransaction(async (tx) => {
      tx.set(db.doc(paths[0]), { status: 'active' });
      tx.set(db.doc(paths[1]), { merchantId, status: 'active' });
      tx.set(db.doc(paths[2]), { merchantId, branchId, deviceId, status: 'active',
        authUid: `device:${deviceId}`, displayName: 'Runtime fixture' });
    });
    // Exercise read/write transactions through the same REST transport as hosting.
    stage = 'Firestore read/write transaction';
    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(db.doc(paths[2]));
      assert.equal(snapshot.get('status'), 'active');
      tx.update(db.doc(paths[2]), { lastSeenAt: new Date() });
    });
    stage = 'Auth signing';
    const customToken = await auth.createCustomToken(`device:${deviceId}`, {
      principalType: 'device', merchantId, deviceId,
    });
    stage = 'Auth sign-in';
    const signedIn = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=test-key`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    });
    const { idToken } = await signedIn.json();
    assert.ok(idToken, 'Emulator custom-token sign-in');
    const commands = createCommandDispatcher(db, (uid, claims) => auth.createCustomToken(uid, claims), hasher);
    const handler = createHttpsHandler({ projectId, environment: 'dev',
      allowedOrigins: [], allowedAppIds: ['test-app'] }, { ...commands,
      verifyIdToken: (token) => auth.verifyIdToken(token, true),
      // App Check has no local emulator. Hosted main has no bypass.
      verifyAppCheckToken: async (token) => {
        assert.equal(token, 'test-attestation'); return { appId: 'test-app' };
      },
    });
    server = createGatewayServer(handler);
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    stage = 'HTTP bootstrap';
    const response = await fetch(`http://127.0.0.1:${server.address().port}/v1/commands/getDeviceBootstrap`, {
      method: 'POST', headers: { 'content-type': 'application/json',
        authorization: `Bearer ${idToken}`, 'x-firebase-appcheck': 'test-attestation',
        'x-sarisupply-environment': 'dev' }, body: '{"data":{}}',
    });
    assert.equal(response.status, 200);
    assert.deepEqual((await response.json()).result, { merchantId, branchId, deviceId, displayName: 'Runtime fixture', merchantName: merchantId, branchName: branchId });
    stage = 'Catalog and stock REST transaction/query';
    const ownerUid = 'deno-runtime-owner';
    paths.push(`merchants/${merchantId}/memberships/${ownerUid}`,
      `merchants/${merchantId}/products/runtime-product`,
      `merchants/${merchantId}/skuRegistry/RUNTIME`,
      `merchants/${merchantId}/inventoryMeta/catalog`,
      `merchants/${merchantId}/catalogChanges/0000000001`,
      `merchants/${merchantId}/catalogOperations/runtime-product`,
      `merchants/${merchantId}/branches/${branchId}/stock/runtime-product`,
      `merchants/${merchantId}/branches/${branchId}/inventoryMeta/stock`,
      `merchants/${merchantId}/branches/${branchId}/stockChanges/0000000001`,
      `merchants/${merchantId}/branches/${branchId}/stockOperations/runtime-opening`);
    await db.doc(paths[paths.length - 10]).set({ userId: ownerUid, merchantId,
      role: 'owner', status: 'active', allBranches: true, branchIds: [] });
    const ownerRequest = { auth: { uid: ownerUid, token: {} } };
    const saved = await commands.dispatch('saveCatalogProduct', ownerRequest, {
      merchantId, operationId: 'runtime-product', expectedRevision: 0,
      product: { id: 'runtime-product', sku: 'RUNTIME', name: 'Runtime item',
        baseUnit: 'piece', active: true,
        units: [{ name: 'piece', factor: 1, priceCentavos: 1250, barcode: '' }] },
    });
    assert.equal(saved.revision, 1);
    const count = { merchantId, branchId, operationId: 'runtime-opening',
      productId: 'runtime-product', kind: 'opening', quantity: 12,
      expectedRevision: 0, reason: 'Runtime fixture' };
    assert.equal((await commands.dispatch('recordStockCount', ownerRequest, count)).status, 'accepted');
    assert.equal((await commands.dispatch('recordStockCount', ownerRequest, count)).status, 'duplicate');
    const page = await commands.dispatch('pullInventory', {
      auth: { uid: `device:${deviceId}`, token: { principalType: 'device', merchantId, deviceId } },
    }, { merchantId, branchId, feed: 'stock', cursor: 0 });
    assert.equal(page.changes.length, 1); assert.equal(page.changes[0].quantity, 12);
    stage = 'Cashier grants and checkout REST reconciliation';
    const cashierId = 'runtime-cashier';
    const cashierPath = `merchants/${merchantId}/cashiers/${cashierId}`;
    const credentialPath = `merchants/${merchantId}/cashierCredentials/${cashierId}`;
    paths.push(cashierPath, credentialPath);
    await db.doc(cashierPath).set({ merchantId, status: 'active', mustChangePin: false, assignedBranchIds: [branchId] });
    await db.doc(credentialPath).set({ ...(await hasher.hash('483920')), credentialVersion: 1 });
    const deviceRequest = { auth: { uid: `device:${deviceId}`, token: { principalType: 'device', merchantId, deviceId } } };
    const verified = await commands.dispatch('verifyCashierPin',deviceRequest,{cashierId,pin:'483920'});
    assert.equal(verified.mustChangePin,false);
    const grant = verified.grant;
    assert.equal(Buffer.from(grant.secret,'base64url').length,32);
    const branchRoot = `merchants/${merchantId}/branches/${branchId}`;
    paths.push(`merchants/${merchantId}/cashierGrants/${grant.scope.grantId}`,
      `${branchRoot}/checkoutDevices/${deviceId}`, `${branchRoot}/checkoutShifts/runtime-shift`,
      `${branchRoot}/checkoutOperations/runtime-shift`, `${branchRoot}/checkoutOperations/runtime-sale`,
      `${branchRoot}/stockChanges/0000000002`);
    const resolved = await commands.dispatch('resolveCatalogQuotes',deviceRequest,{merchantId,branchId,products:[{productId:'runtime-product',revision:1}]});
    assert.equal(resolved.changes[0].sequence,1);
    const op = {id:'runtime-shift',scope:grant.scope,shiftId:'runtime-shift',ordinal:1,occurredAt:grant.issuedAt,kind:'openShift',payload:{floatCentavos:100}};
    assert.equal((await commands.dispatch('recordCheckoutOperation',deviceRequest,{intent:op,grantSecret:grant.secret})).status,'accepted');
    const sale = {...op,id:'runtime-sale',kind:'sale',ordinal:2,payload:{merchantName:'Store',branchName:'Main',
      lines:[{productId:'runtime-product',sku:'RUNTIME',name:'Runtime item',unit:'piece',factor:1,priceCentavos:1250,quantity:1,catalogSequence:1,catalogRevision:1}],
      tender:{kind:'cash',receivedCentavos:1500,reference:'',confirmed:false}}};
    assert.equal((await commands.dispatch('recordCheckoutOperation',deviceRequest,{intent:sale,grantSecret:grant.secret})).sequence,2);
    assert.equal((await commands.dispatch('recordCheckoutOperation',deviceRequest,{intent:sale,grantSecret:grant.secret})).status,'duplicate');
    const sold = await commands.dispatch('pullInventory',deviceRequest,{merchantId,branchId,feed:'stock',cursor:1});
    assert.equal(sold.changes.length,1); assert.equal(sold.changes[0].positions[0].delta,-1);
    assert.equal(sold.changes[0].positions[0].quantity,11);
    const cpu = process.cpuUsage(cpuStart);
    report = { runtime: Deno.version.deno, status: 'PASS',
      elapsedMs: Math.round(performance.now() - started), cpuMs: Math.round((cpu.user + cpu.system) / 1000),
      rssMiB: Math.round(process.memoryUsage().rss / 1024 / 1024),
      scope: 'local scrypt, Admin SDK, grants, catalog quotes and checkout REST replay/feed, token signing and HTTP' };
  } finally {
    stage = 'HTTP cleanup';
    if (server) { server.closeAllConnections(); await new Promise((resolve) => server.close(resolve)); }
    stage = 'Firestore cleanup';
    await Promise.all(paths.map((path) => db.doc(path).delete()));
    stage = 'Auth cleanup';
    try { await auth.deleteUser(`device:${deviceId}`); } catch (error) {
      if (error.code !== 'auth/user-not-found') throw error;
    }
    stage = 'SDK cleanup';
    await deleteApp(app);
    clearTimeout(deadline);
  }
  console.log(JSON.stringify(report));
}
probe().catch((error) => { console.error(error); process.exitCode = 1; });
