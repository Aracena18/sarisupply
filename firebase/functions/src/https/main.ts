import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getAppCheck } from 'firebase-admin/app-check';
import { initializeFirestore } from 'firebase-admin/firestore';
import { createPinHasher } from '../cashier/pin-kdf';
import { createCommandDispatcher } from './commands';
import { readBackendConfig } from './config';
import { createHttpsHandler } from './handler';
import { createGatewayServer } from './server';

const config = readBackendConfig(process.env);
const app = initializeApp({ projectId: config.projectId, credential: cert(config.serviceAccount) });
const auth = getAuth(app);
// Deno 2.5's Node gRPC path fails the local compatibility probe. REST retains
// the Admin SDK's transaction semantics and avoids that transport dependency.
const commands = createCommandDispatcher(initializeFirestore(app, { preferRest: true }),
  (uid, claims) => auth.createCustomToken(uid, claims), createPinHasher(config.pinPepper));
const handler = createHttpsHandler(config, { ...commands,
  verifyIdToken: (token) => auth.verifyIdToken(token, true),
  verifyAppCheckToken: (token) => getAppCheck(app).verifyToken(token),
});
const port = Number(process.env.PORT ?? 8000);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid server port');
const server = createGatewayServer(handler);
server.listen(port, '0.0.0.0');
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => server.close());
}
