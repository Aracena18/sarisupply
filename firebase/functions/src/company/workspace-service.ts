import { FieldPath, FieldValue, Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthRequest, AuthorizationService, CompanyRole, companyRoles } from '../common/authz';
import { requireDocumentId } from '../common/ids';
import { createHash } from 'node:crypto';

const denied = () => new HttpsError('permission-denied', 'Access denied');
function fail(condition: unknown, message: string): void {
  if (!condition) throw new HttpsError('invalid-argument', message);
}
function googleEmail(request: AuthRequest): { uid: string; email: string } {
  const uid = request.auth?.uid;
  const token = request.auth?.token;
  const firebase = token?.firebase as Record<string, unknown> | undefined;
  if (!uid || token?.principalType === 'device') throw new HttpsError('unauthenticated', 'Sign in required');
  if (token?.email_verified !== true || typeof token.email !== 'string' ||
      !token.email.trim() || firebase?.sign_in_provider !== 'google.com') throw denied();
  return { uid, email: token.email.trim().toLowerCase() };
}
function digest(value: unknown): string {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}
function operationId(value: unknown): string {
  return requireDocumentId(value, 'operation ID');
}
function email(value: unknown): string {
  if (typeof value !== 'string' || value.length > 254) throw new HttpsError('invalid-argument', 'Invalid invitation email');
  const normalized = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) throw new HttpsError('invalid-argument', 'Invalid invitation email');
  return normalized;
}
function companyRole(value: unknown): CompanyRole {
  if (value !== 'warehouseOperations' && value !== 'rider') throw new HttpsError('invalid-argument', 'Unsupported staff role');
  return value;
}
function companyContext(
  input: Record<string, unknown>, expectedRole?: CompanyRole,
): { companyId: string; role: CompanyRole } {
  if (input.authorizationVersion !== 1) {
    throw new HttpsError('invalid-argument', 'Unsupported authorization contract version');
  }
  const context = input.context as Record<string, unknown> | undefined;
  if (context?.kind !== 'company' || !companyRoles.includes(context.role as CompanyRole)) {
    throw new HttpsError('invalid-argument', 'Select a supported company context');
  }
  const companyId = requireDocumentId(context.companyId, 'company ID');
  const role = context.role as CompanyRole;
  if (expectedRole !== undefined && role !== expectedRole) throw denied();
  if (input.companyId !== undefined && input.companyId !== companyId) throw denied();
  return { companyId, role };
}
function warehouseIds(value: unknown): string[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > 100) throw new HttpsError('invalid-argument', 'Choose assigned warehouses');
  const ids = value.map(id => requireDocumentId(id, 'warehouse ID'));
  if (new Set(ids).size !== ids.length) throw new HttpsError('invalid-argument', 'Warehouse scope contains duplicates');
  return ids;
}
function assertWorkspacePage(value: unknown): number {
  const pageSize = value === undefined ? 25 : value;
  if (typeof pageSize !== 'number' || !Number.isInteger(pageSize) || pageSize < 1 || pageSize > 50) {
    throw new HttpsError('invalid-argument', 'Page size must be between 1 and 50');
  }
  return pageSize;
}

function workspaceCursor(uid: string, value: unknown): string | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== 'string' || value.length > 512) {
    throw new HttpsError('invalid-argument', 'Invalid workspace cursor');
  }
  try {
    const decoded = JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as Record<string, unknown>;
    if (decoded.version !== 1 || decoded.uid !== uid) throw new Error('wrong subject');
    return requireDocumentId(decoded.after, 'cursor');
  } catch {
    throw new HttpsError('invalid-argument', 'Invalid workspace cursor');
  }
}

function encodeWorkspaceCursor(uid: string, after: string): string {
  return Buffer.from(JSON.stringify({ version: 1, uid, after }), 'utf8').toString('base64url');
}

export async function getAuthorizationWorkspaces(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { uid } = googleEmail(request);
  if (input.authorizationVersion !== 1) {
    throw new HttpsError('invalid-argument', 'Unsupported authorization contract version');
  }
  const pageSize = assertWorkspacePage(input.pageSize);
  const cursor = workspaceCursor(uid, input.cursor);
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    let canAdministerPlatform = false;
    if (request.auth?.token.sarisupplyAdmin === true) {
      try {
        await authority.requirePlatformAdmin(request);
        canAdministerPlatform = true;
      } catch (error) {
        if (!(error instanceof HttpsError) || error.code !== 'permission-denied') throw error;
      }
    }
    const refs = db.collection(`users/${uid}/companyRefs`).orderBy(FieldPath.documentId()).limit(pageSize + 1);
    const query = cursor ? refs.startAfter(cursor) : refs;
    const page = await tx.get(query);
    const entries: Record<string, unknown>[] = [];
    for (const ref of page.docs.slice(0, pageSize)) {
      const data = ref.data();
      const companyId = requireDocumentId(ref.id, 'company ID');
      if (data.companyId !== companyId || data.status !== 'active' || !Array.isArray(data.roleRefs)) continue;
      for (const rawRole of [...new Set(data.roleRefs)]) {
        if (!companyRoles.includes(rawRole as CompanyRole)) continue;
        try {
          const role = rawRole as CompanyRole;
          const { grant, membershipRevision } = await authority.requireCompanyRole(request, companyId, role);
          const company = await tx.get(db.doc(`companies/${companyId}`));
          entries.push({ kind: 'company', companyId, role, scope: grant.scope,
            membershipRevision, roleGrantRevision: grant.revision,
            displayName: typeof company.get('name') === 'string' ? company.get('name') : 'Company' });
        } catch (error) {
          if (!(error instanceof HttpsError) || error.code !== 'permission-denied') throw error;
        }
      }
    }
    return { authorizationVersion: 1, workspaces: entries, canAdministerPlatform,
      source: 'server', verifiedAt: new Date().toISOString(),
      nextCursor: page.size > pageSize ? encodeWorkspaceCursor(uid, page.docs[pageSize - 1].id) : null,
      hasMore: page.size > pageSize };
  });
}

export async function listMyCompanyInvitations(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  if (input.authorizationVersion !== 1) {
    throw new HttpsError('invalid-argument', 'Unsupported authorization contract version');
  }
  const { uid, email: recipientEmail } = googleEmail(request);
  const matches = await db.collectionGroup('invitations')
    .where('recipientEmail', '==', recipientEmail).limit(50).get();
  const invitations: Record<string, unknown>[] = [];
  for (const invite of matches.docs) {
    const data = invite.data();
    const companyId = invite.ref.parent.parent?.id;
    if (!companyId || data.companyId !== companyId || data.status !== 'pending' ||
        !(data.expiresAt instanceof Date || typeof data.expiresAt?.toMillis === 'function') ||
        data.expiresAt.toMillis() <= Date.now() || data.recipientEmail !== recipientEmail ||
        !['warehouseOperations', 'rider'].includes(data.role)) continue;
    const company = await db.doc(`companies/${companyId}`).get();
    if (!company.exists || company.get('status') !== 'active' || company.get('authorizationVersion') !== 1) continue;
    const inviter = requireDocumentId(data.createdBy, 'inviter ID');
    const [member, ownerGrant] = await Promise.all([
      db.doc(`companies/${companyId}/memberships/${inviter}`).get(),
      db.doc(`companies/${companyId}/memberships/${inviter}/roles/companyOwner`).get(),
    ]);
    if (member.get('status') !== 'active' || ownerGrant.get('status') !== 'active' ||
        ownerGrant.get('role') !== 'companyOwner') continue;
    invitations.push({ invitationId: invite.id, companyId, companyName: company.get('name') ?? 'Company',
      role: data.role, warehouseIds: data.warehouseIds, expiresAt: data.expiresAt.toDate().toISOString() });
  }
  return { authorizationVersion: 1, invitations, actorId: uid, source: 'server' };
}

export async function manageCompanyInvitations(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { uid } = googleEmail(request);
  const { companyId } = companyContext(input, 'companyOwner');
  const action = input.action;
  const role = companyRole(input.role);
  const operation = operationId(input.operationId);
  const assigned = warehouseIds(input.warehouseIds);
  if (action !== 'create' && action !== 'revoke') throw new HttpsError('invalid-argument', 'Unknown invitation action');
  if (action === 'revoke') requireDocumentId(input.invitationId, 'invitation ID');
  const recipientEmail = action === 'create' ? email(input.email) : undefined;
  const fingerprint = digest({ companyId, action, role, assigned, recipientEmail,
    invitationId: action === 'revoke' ? input.invitationId : null });
  const root = `companies/${companyId}`;
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    await authority.requireCompanyRole(request, companyId, 'companyOwner');
    const op = db.doc(`${root}/operations/${operation}`);
    const previous = await tx.get(op);
    if (previous.exists) {
      if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists', 'Operation payload conflict');
      return previous.data()?.result;
    }
    const warehouseRefs = assigned.map(id => db.doc(`${root}/warehouses/${id}`));
    const warehouses = await Promise.all(warehouseRefs.map(ref => tx.get(ref)));
    if (warehouses.some((record, index) => !record.exists || record.get('companyId') !== companyId ||
        record.get('warehouseId') !== assigned[index] || record.get('status') !== 'active')) throw denied();
    const now = FieldValue.serverTimestamp();
    if (action === 'create') {
      const invitationId = `invite-${digest({ companyId, operation }).slice(0, 40)}`;
      const invite = db.doc(`${root}/invitations/${invitationId}`);
      const unique = digest({ companyId, recipientEmail, role });
      const key = db.doc(`${root}/invitationKeys/${unique}`);
      const priorKey = await tx.get(key);
      if (priorKey.exists && priorKey.get('expiresAt')?.toMillis() > Date.now()) {
        throw new HttpsError('already-exists', 'An active invitation already exists for this account and role');
      }
      const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
      tx.create(invite, { companyId, invitationId, recipientEmail, role, warehouseIds: assigned,
        status: 'pending', expiresAt, createdBy: uid, createdAt: now, operationId: operation, requestFingerprint: fingerprint });
      tx.set(key, { inviteId: invitationId, expiresAt });
      const result = { authorizationVersion: 1,
        context: { kind: 'company', companyId, role: 'companyOwner' },
        invitationId, companyId, role, status: 'pending', expiresAt: expiresAt.toISOString(), operationId: operation };
      tx.create(op, { fingerprint, result, actorId: uid, action, createdAt: now });
      tx.create(db.doc(`${root}/auditEvents/${operation}`), { authorizationVersion: 1,
        context: { kind: 'company', companyId, role: 'companyOwner' }, actorType: 'human', actorId: uid,
        action: 'companyInvitation.created', targetType: 'invitation', targetId: invitationId,
        operationId: operation, requestFingerprint: fingerprint, outcome: 'accepted', createdAt: now });
      return result;
    }
    const invitationId = requireDocumentId(input.invitationId, 'invitation ID');
    const inviteRef = db.doc(`${root}/invitations/${invitationId}`);
    const invite = await tx.get(inviteRef);
    if (invite.get('companyId') !== companyId || invite.get('status') !== 'pending' ||
        invite.get('role') !== role || digest(invite.get('warehouseIds')) !== digest(assigned)) throw denied();
    const key = db.doc(`${root}/invitationKeys/${digest({ companyId, recipientEmail: invite.get('recipientEmail'), role })}`);
    const result = { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: 'companyOwner' },
      invitationId, companyId, role, status: 'revoked', operationId: operation };
    tx.update(inviteRef, { status: 'revoked', revokedBy: uid, revokedAt: now, revokeOperationId: operation });
    tx.delete(key);
    tx.create(op, { fingerprint, result, actorId: uid, action, createdAt: now });
    tx.create(db.doc(`${root}/auditEvents/${operation}`), { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: 'companyOwner' }, actorType: 'human', actorId: uid,
      action: 'companyInvitation.revoked', targetType: 'invitation', targetId: invitationId,
      operationId: operation, requestFingerprint: fingerprint, outcome: 'accepted', createdAt: now });
    return result;
  });
}

export async function acceptCompanyInvitation(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { uid, email: recipientEmail } = googleEmail(request);
  const selected = companyContext(input);
  const companyId = selected.companyId;
  if (input.role !== selected.role) throw denied();
  const invitationId = requireDocumentId(input.invitationId, 'invitation ID');
  const operation = operationId(input.operationId);
  const root = `companies/${companyId}`;
  const inviteRef = db.doc(`${root}/invitations/${invitationId}`);
  const memberRef = db.doc(`${root}/memberships/${uid}`);
  const roleRef = memberRef.collection('roles').doc(requireCompanyStaffRole(input.role));
  const projectionRef = db.doc(`users/${uid}/companyRefs/${companyId}`);
  const fingerprint = digest({ companyId, invitationId, role: input.role, uid });
  return db.runTransaction(async tx => {
    const [invite, member, grant, projection, op] = await Promise.all([
      tx.get(inviteRef), tx.get(memberRef), tx.get(roleRef), tx.get(projectionRef),
      tx.get(db.doc(`${root}/operations/${operation}`)),
    ]);
    if (op.exists) {
      if (op.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists', 'Operation payload conflict');
      if (invite.get('status') !== 'accepted' || invite.get('acceptedBy') !== uid ||
          member.get('status') !== 'active' || grant.get('status') !== 'active' ||
          grant.get('invitationId') !== invitationId) throw denied();
      return op.get('result');
    }
    const data = invite.data();
    if (!data || data.companyId !== companyId || data.invitationId !== invitationId ||
        data.recipientEmail !== recipientEmail || data.role !== input.role || data.status !== 'pending' ||
        typeof data.expiresAt?.toMillis !== 'function' || data.expiresAt.toMillis() <= Date.now()) throw denied();
    const company = await tx.get(db.doc(root));
    if (company.get('status') !== 'active' || company.get('authorizationVersion') !== 1) throw denied();
    if (member.exists && (member.get('companyId') !== companyId || member.get('userId') !== uid || member.get('status') !== 'active')) {
      throw new HttpsError('failed-precondition', 'Membership needs authorized recovery before acceptance');
    }
    if (grant.exists && grant.get('status') === 'active') throw new HttpsError('already-exists', 'This role is already active');
    const ids = warehouseIds(data.warehouseIds);
    const warehouses = await Promise.all(ids.map(id => tx.get(db.doc(`${root}/warehouses/${id}`))));
    if (warehouses.some((warehouse, index) => !warehouse.exists || warehouse.get('companyId') !== companyId ||
        warehouse.get('warehouseId') !== ids[index] || warehouse.get('status') !== 'active')) throw denied();
    const now = FieldValue.serverTimestamp();
    const membershipRevision = member.exists ? (member.get('revision') as number) + 1 : 1;
    const grantRevision = grant.exists ? (grant.get('revision') as number) + 1 : 1;
    if (!Number.isSafeInteger(membershipRevision) || !Number.isSafeInteger(grantRevision)) throw denied();
    const common = { companyId, userId: uid, status: 'active', createdAt: now, updatedAt: now };
    tx.set(memberRef, { ...(member.exists ? member.data() : {}), ...common, revision: membershipRevision,
      verifiedEmail: recipientEmail });
    tx.set(roleRef, { ...common, role: data.role, revision: grantRevision,
      scope: { kind: 'warehouses', warehouseIds: ids }, createdBy: data.createdBy, invitationId });
    const previousRoles = Array.isArray(projection.get('roleRefs')) ? projection.get('roleRefs') as string[] : [];
    const roleRefs = [...new Set([...previousRoles.filter(name => companyRoles.includes(name as CompanyRole)), data.role])];
    tx.set(projectionRef, { companyId, roleRefs, status: 'active', membershipRevision, updatedAt: now });
    const result = { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: data.role },
      companyId, role: data.role, scope: { kind: 'warehouses', warehouseIds: ids },
      membershipRevision, roleGrantRevision: grantRevision, status: 'accepted', operationId: operation };
    tx.update(inviteRef, { status: 'accepted', acceptedBy: uid, acceptedAt: now,
      acceptedOperationId: operation, acceptedFingerprint: fingerprint });
    tx.create(db.doc(`${root}/operations/${operation}`), { fingerprint, result, actorId: uid,
      action: 'acceptCompanyInvitation', createdAt: now });
    tx.create(db.doc(`${root}/auditEvents/${operation}`), { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: data.role }, actorType: 'human', actorId: uid,
      action: 'companyInvitation.accepted', targetType: 'membership', targetId: uid,
      operationId: operation, requestFingerprint: fingerprint, outcome: 'accepted', createdAt: now });
    return result;
  });
}

function requireCompanyStaffRole(value: unknown): 'warehouseOperations' | 'rider' {
  if (value !== 'warehouseOperations' && value !== 'rider') throw new HttpsError('invalid-argument', 'Unsupported staff role');
  return value;
}

export async function readCompanyStaff(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { companyId } = companyContext(input, 'companyOwner');
  const uid = googleEmail(request).uid;
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    await authority.requireCompanyRole(request, companyId, 'companyOwner');
    const members = await tx.get(db.collection(`companies/${companyId}/memberships`).orderBy(FieldPath.documentId()).limit(51));
    const staff: Record<string, unknown>[] = [];
    for (const member of members.docs) {
      if (member.id === uid || member.get('status') !== 'active') continue;
      for (const role of ['warehouseOperations', 'rider'] as const) {
        const grant = await tx.get(db.doc(`${member.ref.path}/roles/${role}`));
        if (grant.get('status') !== 'active') continue;
        staff.push({ memberId: member.id, email: member.get('verifiedEmail') ?? 'Verified team account',
          role, scope: grant.get('scope'), revision: grant.get('revision') });
      }
    }
    return { authorizationVersion: 1, members: staff, hasMore: members.size > 50, source: 'server' };
  });
}

export async function listCompanyInvitations(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { companyId } = companyContext(input, 'companyOwner');
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    await authority.requireCompanyRole(request, companyId, 'companyOwner');
    const page = await tx.get(db.collection(`companies/${companyId}/invitations`).orderBy('createdAt', 'desc').limit(51));
    const invitations = page.docs.map(doc => {
      const expiresAt = doc.get('expiresAt')?.toDate?.() as Date | undefined;
      const storedStatus = doc.get('status');
      return { invitationId: doc.id, companyId, email: doc.get('recipientEmail'),
        role: doc.get('role'), warehouseIds: doc.get('warehouseIds'),
        status: storedStatus === 'pending' && expiresAt && expiresAt.getTime() <= Date.now()
          ? 'expired' : storedStatus,
        expiresAt: expiresAt?.toISOString() ?? null };
    });
    return { authorizationVersion: 1, invitations, hasMore: page.size > 50, source: 'server' };
  });
}

export async function removeCompanyMemberRole(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { uid } = googleEmail(request);
  const { companyId } = companyContext(input, 'companyOwner');
  const memberId = requireDocumentId(input.memberId, 'member ID');
  const role = requireCompanyStaffRole(input.role);
  const operation = operationId(input.operationId);
  const fingerprint = digest({ companyId, memberId, role });
  const root = `companies/${companyId}`;
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    await authority.requireCompanyRole(request, companyId, 'companyOwner');
    const memberRef = db.doc(`${root}/memberships/${memberId}`);
    const grantRef = memberRef.collection('roles').doc(role);
    const opRef = db.doc(`${root}/operations/${operation}`);
    const [member, grant, previous, projection] = await Promise.all([
      tx.get(memberRef), tx.get(grantRef), tx.get(opRef), tx.get(db.doc(`users/${memberId}/companyRefs/${companyId}`)),
    ]);
    if (previous.exists) {
      if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists', 'Operation payload conflict');
      return previous.get('result');
    }
    if (memberId === uid || member.get('companyId') !== companyId || member.get('userId') !== memberId ||
        member.get('status') !== 'active' || grant.get('companyId') !== companyId ||
        grant.get('userId') !== memberId || grant.get('role') !== role || grant.get('status') !== 'active') throw denied();
    const memberRevision = member.get('revision'), roleRevision = grant.get('revision');
    if (!Number.isSafeInteger(memberRevision) || !Number.isSafeInteger(roleRevision)) throw denied();
    const otherRoles = await Promise.all(companyRoles.filter(value => value !== role)
      .map(value => tx.get(memberRef.collection('roles').doc(value))));
    const stillActive = otherRoles.some(doc => doc.get('status') === 'active');
    const now = FieldValue.serverTimestamp();
    tx.update(grantRef, { status: 'removed', revision: roleRevision + 1, removedBy: uid, removedAt: now });
    tx.update(memberRef, { status: stillActive ? 'active' : 'removed', revision: memberRevision + 1, updatedAt: now });
    const roleRefs = (Array.isArray(projection.get('roleRefs')) ? projection.get('roleRefs') as string[] : [])
      .filter(value => value !== role);
    tx.set(db.doc(`users/${memberId}/companyRefs/${companyId}`), { companyId, roleRefs,
      status: stillActive ? 'active' : 'removed', membershipRevision: memberRevision + 1, updatedAt: now });
    const result = { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: 'companyOwner' },
      memberId, role, status: 'removed', operationId: operation };
    tx.create(opRef, { fingerprint, result, actorId: uid, action: 'removeCompanyMemberRole', createdAt: now });
    tx.create(db.doc(`${root}/auditEvents/${operation}`), { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: 'companyOwner' }, actorType: 'human', actorId: uid,
      action: 'companyMembership.roleRemoved', targetType: 'membership', targetId: memberId,
      operationId: operation, requestFingerprint: fingerprint, outcome: 'accepted', createdAt: now });
    return result;
  });
}

export async function saveCompanyWarehouse(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { companyId } = companyContext(input, 'companyOwner');
  const operation = operationId(input.operationId);
  const name = typeof input.name === 'string' ? input.name.trim() : '';
  const code = typeof input.code === 'string' ? input.code.trim() : '';
  const address = typeof input.address === 'string' ? input.address.trim() : '';
  fail(name.length > 0 && name.length <= 120, 'Enter a warehouse name');
  fail(code.length > 0 && code.length <= 40, 'Enter a warehouse code');
  fail(address.length <= 250, 'Address is too long');
  const fingerprint = digest({ companyId, name, code, address });
  const root = `companies/${companyId}`;
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    const { grant } = await authority.requireCompanyRole(request, companyId, 'companyOwner');
    const opRef = db.doc(`${root}/warehouseOperations/${operation}`);
    const op = await tx.get(opRef);
    if (op.exists) {
      if (op.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists', 'Operation payload conflict');
      return op.get('result');
    }
    if (!grant.revision) throw denied();
    const warehouseId = `warehouse-${operation}`;
    const ref = db.doc(`${root}/warehouses/${warehouseId}`);
    const existing = await tx.get(ref);
    if (existing.exists) throw new HttpsError('already-exists', 'Warehouse ID already exists');
    const now = FieldValue.serverTimestamp();
    tx.create(ref, { companyId, warehouseId, name, code, address, status: 'active', createdBy: request.auth!.uid, createdAt: now, updatedAt: now });
    const result = { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: 'companyOwner' },
      warehouseId, name, code, address, status: 'active', operationId: operation };
    tx.create(opRef, { fingerprint, result, actorId: request.auth!.uid, createdAt: now });
    tx.create(db.doc(`${root}/auditEvents/${operation}`), { authorizationVersion: 1,
      context: { kind: 'company', companyId, role: 'companyOwner' }, actorType: 'human', actorId: request.auth!.uid,
      action: 'companyWarehouse.created', targetType: 'warehouse', targetId: warehouseId,
      operationId: operation, requestFingerprint: fingerprint, outcome: 'accepted', createdAt: now });
    return result;
  });
}

export async function listCompanyWarehouses(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const { companyId, role } = companyContext(input);
  if (input.role !== role) throw denied();
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    const { grant } = await authority.requireCompanyRole(request, companyId, role);
    const page = await tx.get(db.collection(`companies/${companyId}/warehouses`).where('status', '==', 'active').orderBy(FieldPath.documentId()).limit(101));
    const allowed = role === 'companyOwner' ? null : new Set((grant.scope as { warehouseIds: string[] }).warehouseIds);
    const records = page.docs.slice(0, 100).filter(doc => allowed === null || allowed.has(doc.id))
      .map(doc => ({ warehouseId: doc.id, name: doc.get('name'), code: doc.get('code'), address: doc.get('address') }));
    return { authorizationVersion: 1, warehouses: records, hasMore: page.size > 100, source: 'server' };
  });
}

export async function getCompanyWorkspace(
  db: Firestore, request: AuthRequest, input: Record<string, unknown>,
) {
  const context = input.context as Record<string, unknown> | undefined;
  if (input.authorizationVersion !== 1 || context?.kind !== 'company' ||
      !companyRoles.includes(context.role as CompanyRole)) {
    throw new HttpsError('invalid-argument', 'Select a supported company workspace');
  }
  const companyId = requireDocumentId(context.companyId, 'company ID');
  const warehouseId = input.warehouseId === undefined ? undefined :
    requireDocumentId(input.warehouseId, 'warehouse ID');
  const role = context.role as CompanyRole;
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    const { grant, membershipRevision } = await authority.requireCompanyRole(request, companyId, role, warehouseId);
    const company = await tx.get(db.doc(`companies/${companyId}`));
    return {
      authorizationVersion: 1, kind: 'company', companyId, role, scope: grant.scope,
      membershipRevision, roleGrantRevision: grant.revision,
      displayName: typeof company.get('name') === 'string' ? company.get('name') : 'Company',
      source: 'server', verifiedAt: new Date().toISOString(),
    };
  });
}
