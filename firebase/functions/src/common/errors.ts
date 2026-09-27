import { HttpsError } from 'firebase-functions/v2/https';

export function toHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  return new HttpsError('internal', 'Unexpected server error');
}
