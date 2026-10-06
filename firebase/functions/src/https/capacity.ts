import { readFileSync } from 'node:fs';

// Firebase engineering budgets and 80% of published Deno Free ceilings.
const limits = {
  readsDaily: 40_000, writesDaily: 16_000, deletesDaily: 16_000,
  storedBytes: 750 * 1024 * 1024,
  monthlyRequests: 800_000, monthlyCpuMillis: 8 * 60 * 60 * 1000,
  monthlyEgressBytes: 16 * 1024 * 1024 * 1024,
  monthlyInstanceMemoryGiBHours: 120,
};
type Metric = keyof typeof limits;

function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Expected a capacity object');
  return value as Record<string, unknown>;
}

export function evaluateFreeCapacity(value: unknown) {
  const profile = object(value);
  const workload = object(profile.workload);
  const observations = object(profile.observations);
  const evidence = object(profile.evidence);
  const missingEvidence: string[] = [];
  function number(source: Record<string, unknown>, key: string, allowMissing = false): number | null {
    const value = source[key];
    if (allowMissing && (value === null || value === undefined)) {
      missingEvidence.push(key); return null;
    }
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error(`Invalid capacity value: ${key}`);
    return value;
  }
  const stores = number(workload, 'stores')!;
  const receipts = number(workload, 'receiptsPerStoreDaily')!;
  const days = number(workload, 'retentionDays')!;
  if (!Number.isInteger(stores) || stores < 1 || stores > 5 || !Number.isInteger(receipts) ||
    receipts < 1 || receipts > 200 || !Number.isInteger(days) || days < 90) {
    throw new Error('Workload must represent 1–5 stores, 1–200 receipts/store/day and at least 90 retained days');
  }
  const dailyReceipts = stores * receipts;
  const projected: Record<Metric, number | null> = {
    readsDaily: null, writesDaily: null, deletesDaily: null, storedBytes: null,
    monthlyRequests: null, monthlyCpuMillis: null, monthlyEgressBytes: null,
    monthlyInstanceMemoryGiBHours: null,
  };
  for (const [perReceipt, fixed, result, multiplier] of [
    ['receiptReads', 'fixedDailyReads', 'readsDaily', dailyReceipts],
    ['receiptWrites', 'fixedDailyWrites', 'writesDaily', dailyReceipts],
    ['receiptDeletes', 'fixedDailyDeletes', 'deletesDaily', dailyReceipts],
    ['receiptBytesIncludingIndexes', 'fixedStoredBytesIncludingIndexes', 'storedBytes', dailyReceipts * days],
  ] as const) {
    const a = number(observations, perReceipt, true);
    const b = number(observations, fixed, true);
    if (a !== null && b !== null) projected[result] = a * multiplier + b;
  }
  for (const key of ['monthlyRequests', 'monthlyCpuMillis', 'monthlyEgressBytes', 'monthlyInstanceMemoryGiBHours'] as const) {
    projected[key] = number(observations, key, true);
  }
  for (const key of ['accountFreeVerified', 'trafficMeasured', 'firestoreMeteringVerified', 'retentionFeasibilityVerified']) {
    if (evidence[key] !== true) missingEvidence.push(key);
  }
  const exceeded = (Object.keys(limits) as Metric[])
    .filter((key) => projected[key] !== null && projected[key]! > limits[key]);
  return {
    status: exceeded.length ? 'over-budget' : missingEvidence.length ? 'unproven' : 'within-budget',
    dailyReceipts, projected, limits, exceeded, missingEvidence,
  };
}

if (require.main === module) {
  try {
    const path = process.argv[2];
    if (!path) throw new Error('Provide a capacity profile JSON path');
    const report = evaluateFreeCapacity(JSON.parse(readFileSync(path, 'utf8')));
    console.log(JSON.stringify(report, null, 2));
    process.exitCode = report.status === 'within-budget' ? 0 : report.status === 'over-budget' ? 1 : 2;
  } catch {
    console.error('Invalid capacity profile; see docs/engineering/FREE_BACKEND.md');
    process.exitCode = 1;
  }
}
