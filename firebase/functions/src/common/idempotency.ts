import { createHash } from 'node:crypto';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

/** Keep the business writes and result record inside the same transaction. */
export async function runIdempotent<T>(
  operationKey: string,
  handler: (transaction: Transaction) => Promise<T>,
  db: Firestore = getFirestore(),
): Promise<T> {
  if (!operationKey || operationKey.length > 512) {
    throw new HttpsError('invalid-argument', 'Invalid operation key');
  }
  const keyHash = createHash('sha256').update(operationKey).digest('hex');
  const ref = db.collection('_idempotency').doc(keyHash);

  return db.runTransaction(async (transaction) => {
    const previous = await transaction.get(ref);
    if (previous.exists) return previous.get('result') as T;

    const result = await handler(transaction);
    if (result === undefined) {
      throw new HttpsError('internal', 'Idempotent operation has no result');
    }
    transaction.create(ref, {
      result,
      createdAt: FieldValue.serverTimestamp(),
    });
    return result;
  });
}
