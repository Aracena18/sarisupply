import { HttpsError } from 'firebase-functions/v2/https';

export function requireDocumentId(value: unknown, field: string): string {
  if (typeof value !== 'string' ||
      value.length === 0 ||
      value.length > 128 ||
      value.includes('/') ||
      value === '.' ||
      value === '..') {
    throw new HttpsError('invalid-argument', `Invalid ${field}`);
  }
  return value;
}
