import { describe, expect, it } from 'vitest';
import { HttpsError } from 'firebase-functions/v2/https';
import { createHttpsHandler } from '../../src/https/handler';
import { readBackendConfig } from '../../src/https/config';

const projectId = 'sarisupply-dev-aracena18';
const config = {
  environment: 'dev' as const, projectId,
  allowedOrigins: ['https://admin.example.test'], allowedAppIds: ['app-1'],
};
let effects = 0;
function handler(command = async (_name: string, identity: { auth?: { uid: string } }) => {
  effects++;
  return { uid: identity.auth?.uid };
}) {
  return createHttpsHandler(config, {
    verifyIdToken: async (token) => {
      if (token !== 'valid') throw Object.assign(new Error('private credential error'), { code: 'auth/invalid-id-token' });
      return { uid: 'owner-1', aud: projectId,
        iss: `https://securetoken.google.com/${projectId}` };
    },
    verifyAppCheckToken: async (token) => {
      if (token === 'expired') throw Object.assign(new Error('expired'), { code: 'app-check/app-check-token-expired' });
      if (token === 'other-app') return { appId: 'app-2' };
      if (token !== 'app-check') throw Object.assign(new Error('private attestation error'), { code: 'app-check/invalid-argument' });
      return { appId: 'app-1' };
    },
    dispatch: command,
    hasCommand: (name) => name === 'getDeviceBootstrap',
  });
}
function request(options: { headers?: Record<string, string>; body?: string; method?: string } = {}) {
  return new Request('https://api.example.test/v1/commands/getDeviceBootstrap', {
    method: options.method ?? 'POST',
    headers: { 'content-type': 'application/json', authorization: 'Bearer valid',
      'x-firebase-appcheck': 'app-check', 'x-sarisupply-environment': 'dev',
      ...options.headers },
    ...(options.method === 'OPTIONS' || options.method === 'GET' ? {} :
      { body: options.body ?? '{"data":{}}' }),
  });
}

describe('HTTPS trust boundary', () => {
  it('uses verified identity and ignores caller-supplied authority', async () => {
    const response = await handler()(request({ body: '{"data":{},"auth":{"uid":"admin"}}' }));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ result: { uid: 'owner-1' } });
    expect(response.headers.get('cache-control')).toBe('no-store');
  });
  it.each([
    ['authorization', '', 401, 'unauthenticated'],
    ['authorization', 'Bearer forged', 401, 'unauthenticated'],
    ['x-firebase-appcheck', '', 503, 'unavailable'],
    ['x-firebase-appcheck', 'forged', 503, 'unavailable'],
    ['x-firebase-appcheck', 'expired', 503, 'unavailable'],
    ['x-firebase-appcheck', 'other-app', 503, 'unavailable'],
    ['x-sarisupply-environment', 'prod', 503, 'unavailable'],
    ['origin', 'https://untrusted.example.test', 503, 'unavailable'],
  ])('rejects %s=%s without executing a command', async (header, value, status, code) => {
    const before = effects;
    const response = await handler()(request({ headers: { [header]: value } }));
    expect(response.status).toBe(status);
    expect(await response.json()).toMatchObject({ error: { code } });
    expect(effects).toBe(before);
  });
  it('rejects a token from another Firebase project', async () => {
    const response = await createHttpsHandler(config, {
      verifyIdToken: async () => ({ uid: 'owner-1', aud: 'other-project', iss: 'other' }),
      verifyAppCheckToken: async () => ({ appId: 'app-1' }),
      hasCommand: () => true, dispatch: async () => { throw new Error('must not dispatch'); },
    })(request());
    expect(response.status).toBe(401);
  });
  it('reports verifier outages as retryable, not an authoritative identity denial', async () => {
    const response = await createHttpsHandler(config, {
      verifyIdToken: async () => { throw Object.assign(new Error('network timeout'), { code: 'auth/internal-error' }); },
      verifyAppCheckToken: async () => ({ appId: 'app-1' }),
      hasCommand: () => true, dispatch: async () => { throw new Error('must not dispatch'); },
    })(request());
    expect(response.status).toBe(503);
    expect(await response.json()).toMatchObject({ error: { code: 'unavailable' } });
  });
  it('keeps revoked identity authoritative even when attestation is missing', async () => {
    const response = await createHttpsHandler(config, {
      verifyIdToken: async () => { throw Object.assign(new Error('revoked'), { code: 'auth/id-token-revoked' }); },
      verifyAppCheckToken: async () => { throw new Error('must not verify'); },
      hasCommand: () => true, dispatch: async () => { throw new Error('must not dispatch'); },
    })(request({ headers: { 'x-firebase-appcheck': '' } }));
    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ error: { code: 'unauthenticated' } });
  });
  it('allows a browser preflight without tokens, scoped to the configured origin', async () => {
    const response = await handler()(request({ method: 'OPTIONS', headers: {
      origin: 'https://admin.example.test', 'access-control-request-method': 'POST',
    } }));
    expect(response.status).toBe(204);
    expect(response.headers.get('access-control-allow-origin')).toBe('https://admin.example.test');
    expect(response.headers.get('access-control-allow-methods')).toBe('POST');
  });
  it.each(['[]', '{"data":[]}', '{"data":null}', 'broken'])('rejects malformed command data: %s', async (body) => {
    const response = await handler()(request({ body }));
    expect(response.status).toBe(400);
  });
  it('bounds the actual streamed body even without Content-Length', async () => {
    const response = await handler()(request({ body: JSON.stringify({ data: { value: 'x'.repeat(65536) } }) }));
    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ error: { code: 'resource-exhausted' } });
  });
  it('does not expose exception details, credentials, or payloads', async () => {
    const response = await handler(async () => { throw new Error('PIN=123456 private_key=secret'); })(request());
    expect(response.status).toBe(500);
    expect(await response.json()).toEqual({ error: { code: 'internal', message: 'Unexpected server error' } });
  });
  it('preserves current domain denial codes', async () => {
    const response = await handler(async () => { throw new HttpsError('permission-denied', 'Device revoked'); })(request());
    expect(response.status).toBe(403);
    expect(await response.json()).toEqual({ error: { code: 'permission-denied', message: 'Device revoked' } });
  });
  it('rejects unsupported methods and unknown command names', async () => {
    expect((await handler()(request({ method: 'GET' }))).status).toBe(405);
    expect((await handler()(new Request('https://api.example.test/v1/commands/unknown', {
      method: 'POST', body: '{"data":{}}',
    }))).status).toBe(404);
  });
});

const env = {
  SARISUPPLY_ENVIRONMENT: 'dev', FIREBASE_PROJECT_ID: projectId,
  FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ project_id: projectId,
    client_email: 'trusted@project.iam.gserviceaccount.com', private_key: 'private-server-key' }),
  CASHIER_PIN_PEPPER: 'test-only-pepper-12345678901234567890',
  ALLOWED_ORIGINS: 'https://admin.example.test', ALLOWED_APP_IDS: 'app-1',
};
describe('fail-closed deployment configuration', () => {
  it('accepts explicit matching configuration', () => {
    expect(readBackendConfig(env)).toMatchObject(config);
  });
  it.each(['SARISUPPLY_ENVIRONMENT', 'FIREBASE_PROJECT_ID', 'FIREBASE_SERVICE_ACCOUNT_JSON',
    'CASHIER_PIN_PEPPER', 'ALLOWED_ORIGINS', 'ALLOWED_APP_IDS'])('rejects missing %s', (key) => {
    expect(() => readBackendConfig({ ...env, [key]: '' })).toThrow();
  });
  it('rejects project/environment or credential mismatches', () => {
    expect(() => readBackendConfig({ ...env, SARISUPPLY_ENVIRONMENT: 'prod' })).toThrow();
    expect(() => readBackendConfig({ ...env, FIREBASE_SERVICE_ACCOUNT_JSON: '{"project_id":"other"}' })).toThrow();
  });
  it('rejects emulator endpoints in deployed config', () => {
    expect(() => readBackendConfig({ ...env, FIRESTORE_EMULATOR_HOST: 'localhost:8080' })).toThrow();
  });
  it('rejects wildcard and non-HTTPS production origins', () => {
    expect(() => readBackendConfig({ ...env, ALLOWED_ORIGINS: '*' })).toThrow();
    expect(() => readBackendConfig({ ...env, ALLOWED_ORIGINS: 'http://example.test' })).toThrow();
  });
});
