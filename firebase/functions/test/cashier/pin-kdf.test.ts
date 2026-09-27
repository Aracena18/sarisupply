import { describe, expect, it } from 'vitest';
import { createPinHasher } from '../../src/cashier/pin-kdf';

describe('cashier PIN KDF', () => {
  const hasher = createPinHasher('a-strong-server-only-pepper-value-1234567890');

  it('verifies the right PIN and rejects a wrong one', async () => {
    const credential = await hasher.hash('123456');
    expect(await hasher.verify('123456', credential)).toBe(true);
    expect(await hasher.verify('654321', credential)).toBe(false);
    expect(JSON.stringify(credential)).not.toContain('123456');
  });

  it('uses a random salt for each credential', async () => {
    const a = await hasher.hash('1234');
    const b = await hasher.hash('1234');
    expect(a.salt).not.toBe(b.salt);
    expect(a.hash).not.toBe(b.hash);
  });

  it('rejects invalid PINs and an absent pepper', async () => {
    expect(() => createPinHasher('')).toThrow(/pepper/i);
    await expect(hasher.hash('123')).rejects.toThrow(/PIN/i);
    await expect(hasher.hash('1234567')).rejects.toThrow(/PIN/i);
    await expect(hasher.hash('abcd')).rejects.toThrow(/PIN/i);
  });
});
