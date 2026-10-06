import { HttpsError } from 'firebase-functions/v2/https';
import { AuthRequest } from '../common/authz';
import { toHttpsError } from '../common/errors';
import { BackendConfig } from './config';

export interface HttpsDependencies {
  verifyIdToken(token: string): Promise<Record<string, unknown> & { uid: string }>;
  verifyAppCheckToken(token: string): Promise<{ appId: string }>;
  hasCommand(name: string): boolean;
  dispatch(name: string, identity: AuthRequest, data: Record<string, unknown>): Promise<unknown>;
}
const statusCodes: Record<string, number> = {
  'invalid-argument': 400, 'failed-precondition': 400, 'out-of-range': 400,
  unauthenticated: 401, 'permission-denied': 403, 'not-found': 404,
  'already-exists': 409, aborted: 409, 'resource-exhausted': 429,
  cancelled: 499, unimplemented: 501, unavailable: 503, 'deadline-exceeded': 504,
};
const maxBodyBytes = 64 * 1024;

async function readData(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) {
    throw new HttpsError('invalid-argument', 'JSON content type required');
  }
  const reader = request.body?.getReader();
  if (!reader) throw new HttpsError('invalid-argument', 'Request data required');
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      size += chunk.value.byteLength;
      if (size > maxBodyBytes) {
        await reader.cancel();
        throw new HttpsError('resource-exhausted', 'Request too large');
      }
      chunks.push(chunk.value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  let envelope: unknown;
  try { envelope = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { throw new HttpsError('invalid-argument', 'Invalid JSON'); }
  if (!envelope || typeof envelope !== 'object' || Array.isArray(envelope)) {
    throw new HttpsError('invalid-argument', 'Request must be an object');
  }
  const data = (envelope as Record<string, unknown>).data;
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object');
  }
  return data as Record<string, unknown>;
}

export function createHttpsHandler(
  config: Pick<BackendConfig, 'environment' | 'projectId' | 'allowedOrigins' | 'allowedAppIds'>,
  dependencies: HttpsDependencies,
): (request: Request) => Promise<Response> {
  return async (request) => {
    const headers = new Headers({ 'content-type': 'application/json',
      'cache-control': 'no-store', vary: 'Origin', 'x-content-type-options': 'nosniff' });
    const json = (value: unknown, status: number) => new Response(JSON.stringify(value), { status, headers });
    try {
      const origin = request.headers.get('origin');
      if (origin) {
        if (!config.allowedOrigins.includes(origin)) throw new HttpsError('unavailable', 'Origin not allowed');
        headers.set('access-control-allow-origin', origin);
      }
      const match = /^\/v1\/commands\/([A-Za-z]+)$/.exec(new URL(request.url).pathname);
      if (!match || !dependencies.hasCommand(match[1])) throw new HttpsError('not-found', 'Unknown command');
      if (request.method === 'OPTIONS') {
        if (!origin || request.headers.get('access-control-request-method') !== 'POST') {
          throw new HttpsError('invalid-argument', 'Invalid preflight');
        }
        headers.set('access-control-allow-methods', 'POST');
        headers.set('access-control-allow-headers', 'Content-Type, Authorization, X-Firebase-AppCheck, X-SariSupply-Environment');
        return new Response(null, { status: 204, headers });
      }
      if (request.method !== 'POST') return json({ error: { code: 'invalid-argument', message: 'POST required' } }, 405);
      if (request.headers.get('x-sarisupply-environment') !== config.environment) {
        throw new HttpsError('unavailable', 'Environment mismatch');
      }
      const bearer = /^Bearer (\S+)$/.exec(request.headers.get('authorization') ?? '');
      const appToken = request.headers.get('x-firebase-appcheck');
      if (!bearer) throw new HttpsError('unauthenticated', 'Authentication required');
      let token: Awaited<ReturnType<HttpsDependencies['verifyIdToken']>>;
      // Only identity/account denials may invalidate the POS's offline authority.
      // Verify identity first so failed attestation cannot mask known revocation.
      try {
        token = await dependencies.verifyIdToken(bearer[1]);
      } catch (error) {
        const code = (error as { code?: string })?.code;
        if (code && ['auth/argument-error', 'auth/invalid-id-token', 'auth/id-token-expired',
          'auth/id-token-revoked', 'auth/user-disabled', 'auth/user-not-found'].includes(code)) {
          throw new HttpsError('unauthenticated', 'Invalid authentication');
        }
        throw new HttpsError('unavailable', 'Authentication service unavailable');
      }
      if (!token.uid || token.aud !== config.projectId ||
        token.iss !== `https://securetoken.google.com/${config.projectId}`) {
        throw new HttpsError('unauthenticated', 'Invalid authentication');
      }
      if (!appToken) throw new HttpsError('unavailable', 'App verification unavailable');
      let app: { appId: string };
      try { app = await dependencies.verifyAppCheckToken(appToken); }
      catch { throw new HttpsError('unavailable', 'App verification unavailable'); }
      if (!config.allowedAppIds.includes(app.appId)) throw new HttpsError('unavailable', 'App not allowed');
      const result = await dependencies.dispatch(match[1], { auth: { uid: token.uid, token } }, await readData(request));
      return json({ result }, 200);
    } catch (error) {
      const safe = toHttpsError(error);
      const status = safe.code === 'resource-exhausted' && safe.message === 'Request too large'
        ? 413 : statusCodes[safe.code] ?? 500;
      return json({ error: { code: safe.code, message: safe.message } }, status);
    }
  };
}
