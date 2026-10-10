import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { requireDocumentId } from './ids';

export interface AuditEventInput {
  merchantId: string;
  actorType: 'human' | 'device' | 'cashier' | 'platformAdmin' | 'companyOwner';
  actorId: string;
  action: string;
  targetType: string;
  targetId: string;
  branchId?: string;
  operationId?: string;
  details?: Record<string, unknown>;
}

export async function writeAuditEvent(
  input: AuditEventInput,
  transaction?: Transaction,
  db: Firestore = getFirestore(),
): Promise<string> {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  requireDocumentId(input.actorId, 'actor ID');
  requireDocumentId(input.targetId, 'target ID');
  if (!input.action.trim() || !input.targetType.trim()) {
    throw new HttpsError('invalid-argument', 'Audit action and target are required');
  }
  if (input.branchId !== undefined) {
    requireDocumentId(input.branchId, 'branch ID');
  }

  const ref = db.collection(`merchants/${merchantId}/auditEvents`).doc();
  const event = {
    merchantId,
    actorType: input.actorType,
    actorId: input.actorId,
    action: input.action,
    targetType: input.targetType,
    targetId: input.targetId,
    ...(input.branchId ? { branchId: input.branchId } : {}),
    ...(input.operationId ? { operationId: input.operationId } : {}),
    ...(input.details ? { details: input.details } : {}),
    createdAt: FieldValue.serverTimestamp(),
  };

  if (transaction) {
    transaction.create(ref, event);
  } else {
    await ref.create(event);
  }
  return ref.id;
}
