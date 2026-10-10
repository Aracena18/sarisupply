import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { Auth, getAuth } from 'firebase-admin/auth';
import { FieldValue, Firestore, getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';
import { requireDocumentId } from '../common/ids';

/** Trusted operator tooling only. Never register this as a client command. */
export async function provisionCompanyOwner(auth: Auth, db: Firestore, input: {
  companyId: string; name: string; email: string; operatorUid: string; operationId: string;
}): Promise<string> {
  const companyId = requireDocumentId(input.companyId, 'company ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const operatorUid = requireDocumentId(input.operatorUid, 'operator UID');
  const name = input.name.trim();
  if (!name || name.length > 200) throw new Error('Company name is required (maximum 200 characters)');
  const user = await auth.getUserByEmail(input.email.trim().toLowerCase());
  requireDocumentId(user.uid, 'owner UID');
  const operator = await auth.getUser(operatorUid);
  if (operator.disabled) throw new Error('Operator account is disabled');
  if (user.disabled || !user.emailVerified ||
      !user.providerData.some(provider => provider.providerId === 'google.com')) {
    throw new Error('Owner must be an existing active verified Google account');
  }
  const fingerprint = createHash('sha256').update(JSON.stringify({
    companyId, name, uid: user.uid, operatorUid,
  })).digest('hex');
  const company = db.doc(`companies/${companyId}`);
  const membership = company.collection('memberships').doc(user.uid);
  const grant = membership.collection('roles').doc('companyOwner');
  const operation = company.collection('provisioningOperations').doc(operationId);
  await db.runTransaction(async tx => {
    const companies = await tx.get(db.collection('companies').limit(2));
    if (companies.docs.some(doc => doc.id !== companyId)) {
      throw new Error('Only one supplying company is supported; no automatic ownership migration');
    }
    const current = await tx.get(company);
    const member = await tx.get(membership);
    const role = await tx.get(grant);
    const previous = await tx.get(operation);
    if (current.exists && (current.get('companyId') !== companyId || current.get('ownerUid') !== user.uid ||
        current.get('status') !== 'active' || current.get('authorizationVersion') !== 1 ||
        member.get('companyId') !== companyId || member.get('userId') !== user.uid ||
        member.get('status') !== 'active' || role.get('status') !== 'active' ||
        role.get('companyId') !== companyId || role.get('userId') !== user.uid ||
        role.get('role') !== 'companyOwner' || role.get('scope.kind') !== 'company')) {
      throw new Error('Company is already provisioned or access was removed; explicit recovery required');
    }
    if (previous.exists) {
      if (previous.get('fingerprint') !== fingerprint) throw new Error('Operation payload conflict');
      return;
    }
    if (current.exists) throw new Error('Company Owner already provisioned; replay the original operation ID');
    const createdAt = FieldValue.serverTimestamp();
    tx.create(company, { companyId, name, ownerUid: user.uid, status: 'active', authorizationVersion: 1, createdAt });
    const common = { companyId, userId: user.uid, status: 'active', revision: 1, createdAt, updatedAt: createdAt };
    tx.create(membership, common);
    tx.create(grant, { ...common, role: 'companyOwner', scope: { kind: 'company' }, createdBy: operatorUid });
    tx.set(db.doc(`users/${user.uid}/companyRefs/${companyId}`), {
      companyId, roleRefs: ['companyOwner'], status: 'active', membershipRevision: 1, updatedAt: createdAt,
    });
    tx.create(operation, { fingerprint, uid: user.uid, operatorUid, operationId, createdAt });
    tx.create(company.collection('auditEvents').doc(operationId), {
      authorizationVersion: 1, context: { kind: 'company', companyId, role: 'companyOwner' },
      actorType: 'human', actorId: operatorUid, provisioningAuthority: 'trustedAdminSdk',
      beneficiaryUid: user.uid, action: 'provisionCompanyOwner', operationId,
      requestFingerprint: fingerprint, outcome: 'accepted', createdAt,
    });
  });
  return user.uid;
}

async function main() {
  const argument = (flag: string) => {
    const index = process.argv.indexOf(flag);
    const value = index < 0 ? undefined : process.argv[index + 1];
    if (!value || value.startsWith('--')) throw new Error(`Missing ${flag}`);
    return value;
  };
  const projectId = argument('--project');
  if (!['sarisupply-dev-aracena18', 'sarisupply-prod-aracena18'].includes(projectId)) {
    throw new Error('Select a SariSupply project explicitly');
  }
  const input = { companyId: argument('--company'), name: argument('--name'),
    email: argument('--email'), operatorUid: argument('--operator'), operationId: argument('--operation') };
  const app = initializeApp({ credential: applicationDefault(), projectId });
  const uid = await provisionCompanyOwner(getAuth(app), getFirestore(app), input);
  process.stdout.write(`Company Owner provisioned in ${projectId}: ${uid}\n`);
}

if (require.main === module) void main().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : 'Provisioning failed'}\n`);
  process.exitCode = 1;
});
