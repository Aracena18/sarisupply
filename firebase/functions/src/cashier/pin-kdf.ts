import { createHmac, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { HttpsError } from 'firebase-functions/v2/https';

export interface StoredPinHash {
  salt: string;
  hash: string;
}

const pinPattern = /^\d{4,6}$/;
const scryptOptions = { N: 16384, r: 8, p: 1, maxmem: 32 * 1024 * 1024 };

function derive(pin: string, salt: Buffer, pepper: string): Promise<Buffer> {
  const password = createHmac('sha256', pepper).update(pin, 'utf8').digest();
  return new Promise((resolve, reject) => {
    scrypt(password, salt, 32, scryptOptions, (error, key) => {
      if (error) reject(error);
      else resolve(key);
    });
  });
}

export function createPinHasher(pepper: string | undefined) {
  if (!pepper || pepper.length < 32) {
    throw new Error('CASHIER_PIN_PEPPER is missing or too short');
  }
  return {
    async hash(pin: string): Promise<StoredPinHash> {
      if (!pinPattern.test(pin)) throw new HttpsError('invalid-argument', 'Invalid PIN');
      const salt = randomBytes(16);
      const hash = await derive(pin, salt, pepper);
      return { salt: salt.toString('base64'), hash: hash.toString('base64') };
    },
    async verify(pin: string, stored: StoredPinHash): Promise<boolean> {
      if (!pinPattern.test(pin)) return false;
      const salt = Buffer.from(stored.salt, 'base64');
      const expected = Buffer.from(stored.hash, 'base64');
      if (salt.length !== 16 || expected.length !== 32) return false;
      const actual = await derive(pin, salt, pepper);
      return timingSafeEqual(actual, expected);
    },
  };
}
