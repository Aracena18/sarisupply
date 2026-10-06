import { once } from 'node:events';
import { afterEach, describe, expect, it } from 'vitest';
import { createGatewayServer } from '../../src/https/server';
import { Server } from 'node:http';
import { createHttpsHandler } from '../../src/https/handler';

let server: Server | undefined;
afterEach(async () => {
  if (server) {
    server.closeAllConnections();
    await new Promise<void>((resolve) => server!.close(() => resolve()));
  }
});
describe('Node/Deno HTTP bridge', () => {
  it('forwards a streamed POST and preserves response status and headers', async () => {
    server = createGatewayServer(async (request) => new Response(JSON.stringify({
      method: request.method, path: new URL(request.url).pathname,
      auth: request.headers.get('authorization'), data: await request.json(),
    }), { status: 403, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } }));
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const address = server.address() as { port: number };
    const response = await fetch(`http://127.0.0.1:${address.port}/v1/commands/getDeviceBootstrap`, {
      method: 'POST', headers: { authorization: 'Bearer test' }, body: '{"data":{}}',
    });
    expect(response.status).toBe(403);
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(await response.json()).toEqual({ method: 'POST', path: '/v1/commands/getDeviceBootstrap',
      auth: 'Bearer test', data: { data: {} } });
  });
  it('returns a typed payload limit error over a real HTTP connection', async () => {
    const projectId = 'test-project';
    server = createGatewayServer(createHttpsHandler({ environment: 'dev', projectId,
      allowedOrigins: [], allowedAppIds: ['test-app'] }, {
      verifyIdToken: async () => ({ uid: 'device-1', aud: projectId, iss: `https://securetoken.google.com/${projectId}` }),
      verifyAppCheckToken: async () => ({ appId: 'test-app' }),
      hasCommand: () => true, dispatch: async () => { throw new Error('must not execute'); },
    }));
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const response = await fetch(`http://127.0.0.1:${(server.address() as { port: number }).port}/v1/commands/getDeviceBootstrap`, {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: 'Bearer test',
        'x-firebase-appcheck': 'test', 'x-sarisupply-environment': 'dev' },
      body: JSON.stringify({ data: { value: 'x'.repeat(100000) } }),
    });
    expect(response.status).toBe(413);
    expect(await response.json()).toMatchObject({ error: { code: 'resource-exhausted' } });
  });
});
