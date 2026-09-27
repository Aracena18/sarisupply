import { describe, expect, it } from 'vitest';
import { cooldownMsForFailure, nextFailure, resetFailures } from '../../src/cashier/pin-rate-limit';

describe('cashier PIN rate limiting', () => {
  it('backs off from the fifth failure and caps at fifteen minutes', () => {
    expect([1, 2, 3, 4].map(cooldownMsForFailure)).toEqual([0, 0, 0, 0]);
    expect(cooldownMsForFailure(5)).toBe(30_000);
    expect(cooldownMsForFailure(6)).toBe(60_000);
    expect(cooldownMsForFailure(7)).toBe(120_000);
    expect(cooldownMsForFailure(20)).toBe(900_000);
  });

  it('records a lock expiry and clears it on success', () => {
    expect(nextFailure(4, 1000)).toEqual({ failedAttemptCount: 5, lockedUntilMs: 31_000 });
    expect(resetFailures()).toEqual({ failedAttemptCount: 0, lockedUntilMs: null });
  });
});
