export function cooldownMsForFailure(failedAttemptCount: number): number {
  if (failedAttemptCount < 5) return 0;
  return Math.min(900_000, 30_000 * 2 ** Math.min(failedAttemptCount - 5, 5));
}

export function nextFailure(previousCount: number, nowMs: number) {
  const failedAttemptCount = Math.max(0, previousCount) + 1;
  const cooldown = cooldownMsForFailure(failedAttemptCount);
  return {
    failedAttemptCount,
    lockedUntilMs: cooldown ? nowMs + cooldown : null,
  };
}

export function resetFailures() {
  return { failedAttemptCount: 0, lockedUntilMs: null };
}
