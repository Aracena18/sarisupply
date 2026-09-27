import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { grantPlatformAdmin } from './admin-service';

const allowedProjects = new Set([
  'sarisupply-dev-aracena18',
  'sarisupply-prod-aracena18',
]);

function argument(flag: string): string | undefined {
  const index = process.argv.indexOf(flag);
  return index < 0 ? undefined : process.argv[index + 1];
}

async function main(): Promise<void> {
  const projectId = argument('--project');
  const uid = argument('--uid');
  const email = argument('--email');
  if (!projectId || !allowedProjects.has(projectId) || Boolean(uid) === Boolean(email)) {
    throw new Error(
      'Usage: npm run grant-admin -- --project <SariSupply project ID> ' +
      '(--uid <Firebase UID> | --email <existing Firebase user email>)',
    );
  }

  const app = initializeApp({
    credential: applicationDefault(),
    projectId,
  });
  const grantedUid = await grantPlatformAdmin(
    getAuth(app),
    getFirestore(app),
    { uid, email },
  );
  process.stdout.write(`Granted SariSupply Admin in ${projectId} to ${grantedUid}\n`);
}

void main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});
