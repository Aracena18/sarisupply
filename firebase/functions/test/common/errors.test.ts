import { HttpsError } from 'firebase-functions/v2/https';
import { describe, expect, it } from 'vitest';
import { toHttpsError } from '../../src/common/errors';

describe('toHttpsError', () => {
  it('preserves expected callable errors', () => {
    const expected = new HttpsError('permission-denied', 'Access denied');
    expect(toHttpsError(expected)).toBe(expected);
  });

  it('does not leak unexpected server error details to clients', () => {
    const result = toHttpsError(new Error('private backend detail'));
    expect(result.code).toBe('internal');
    expect(result.message).not.toContain('private backend detail');
  });
});
