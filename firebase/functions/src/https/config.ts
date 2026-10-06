export interface BackendConfig {
  environment: 'dev' | 'prod';
  projectId: string;
  allowedOrigins: string[];
  allowedAppIds: string[];
  serviceAccount: { projectId: string; clientEmail: string; privateKey: string };
  pinPepper: string;
}

export function readBackendConfig(env: Record<string, string | undefined>): BackendConfig {
  function required(name: string): string {
    const value = env[name]?.trim();
    if (!value) throw new Error(`Missing server setting: ${name}`);
    return value;
  }
  const environment = required('SARISUPPLY_ENVIRONMENT');
  if (environment !== 'dev' && environment !== 'prod') throw new Error('Invalid environment');
  const projectId = required('FIREBASE_PROJECT_ID');
  if (projectId !== `sarisupply-${environment}-aracena18`) throw new Error('Project/environment mismatch');
  for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST',
    'FIREBASE_STORAGE_EMULATOR_HOST', 'FUNCTIONS_EMULATOR']) {
    if (env[name]) throw new Error('Emulator configuration is forbidden in the hosted backend');
  }
  let account: Record<string, unknown>;
  try { account = JSON.parse(required('FIREBASE_SERVICE_ACCOUNT_JSON')); }
  catch { throw new Error('Invalid service account configuration'); }
  if (!account || account.project_id !== projectId ||
    typeof account.client_email !== 'string' || !account.client_email ||
    typeof account.private_key !== 'string' || !account.private_key) {
    throw new Error('Invalid or mismatched service account configuration');
  }
  const pinPepper = required('CASHIER_PIN_PEPPER');
  if (pinPepper.length < 32) throw new Error('PIN pepper must contain at least 32 characters');
  const allowedOrigins = required('ALLOWED_ORIGINS').split(',').map((v) => v.trim());
  for (const origin of allowedOrigins) {
    let url: URL;
    try { url = new URL(origin); } catch { throw new Error('Invalid allowed origin'); }
    if (url.origin !== origin || (url.protocol !== 'https:' &&
      !(environment === 'dev' && url.protocol === 'http:' &&
        ['localhost', '127.0.0.1'].includes(url.hostname)))) {
      throw new Error('Invalid allowed origin');
    }
  }
  const allowedAppIds = required('ALLOWED_APP_IDS').split(',').map((v) => v.trim());
  if (allowedAppIds.some((v) => !v || v === '*')) throw new Error('Invalid allowed app IDs');
  return { environment, projectId, allowedOrigins, allowedAppIds, pinPepper,
    serviceAccount: { projectId, clientEmail: account.client_email, privateKey: account.private_key } };
}
