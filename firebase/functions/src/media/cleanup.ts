import { cert, deleteApp, initializeApp } from 'firebase-admin/app';
import { initializeFirestore } from 'firebase-admin/firestore';
import { readBackendConfig } from '../https/config';
import { mediaFromEnvironment } from './cloudinary';
import { cleanupProductImages } from './product-image-service';

async function main() {
  const config = readBackendConfig(process.env);
  const provider = mediaFromEnvironment(process.env);
  if (!provider) throw Error('Configure Cloudinary before running photo cleanup');
  const app = initializeApp({ projectId: config.projectId, credential: cert(config.serviceAccount) });
  const db = initializeFirestore(app, { preferRest: true });
  // Bounded operator run; repeat daily, or repeat manually while hasMore is true.
  const result = await cleanupProductImages(db, provider);
  console.log(JSON.stringify(result));
  await deleteApp(app);
  if (result.failed) process.exitCode = 1;
}
main().catch(() => { console.error('Photo cleanup failed; check private server configuration and retry.'); process.exitCode = 1; });
