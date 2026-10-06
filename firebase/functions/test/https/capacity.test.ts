import { describe, expect, it } from 'vitest';
import { evaluateFreeCapacity } from '../../src/https/capacity';

const fixture = {
  workload: { stores: 5, receiptsPerStoreDaily: 200, retentionDays: 90 },
  observations: { receiptReads: 10, receiptWrites: 10, receiptDeletes: 1,
    receiptBytesIncludingIndexes: 4096, fixedDailyReads: 5000, fixedDailyWrites: 2000,
    fixedDailyDeletes: 1000, fixedStoredBytesIncludingIndexes: 100 * 1024 * 1024,
    monthlyRequests: 50000, monthlyCpuMillis: 1000000, monthlyEgressBytes: 1024 * 1024 * 1024,
    monthlyInstanceMemoryGiBHours: 100 },
  evidence: { accountFreeVerified: true, trafficMeasured: true,
    firestoreMeteringVerified: true, retentionFeasibilityVerified: true },
};
describe('free capacity gate', () => {
  it('accounts for receipts, other operations, retained records and indexes', () => {
    expect(evaluateFreeCapacity(fixture)).toMatchObject({ status: 'within-budget', dailyReceipts: 1000,
      projected: { readsDaily: 15000, writesDaily: 12000, deletesDaily: 2000,
        storedBytes: 473497600 } });
  });
  it('does not pass missing load/account/archive evidence', () => {
    expect(evaluateFreeCapacity({ ...fixture, evidence: { ...fixture.evidence,
      accountFreeVerified: false } }).status).toBe('unproven');
    expect(evaluateFreeCapacity({ ...fixture, observations: { ...fixture.observations,
      receiptReads: null } }).status).toBe('unproven');
  });
  it('rejects Firestore writes even when the other budgets fit', () => {
    const report = evaluateFreeCapacity({ ...fixture, observations: { ...fixture.observations,
      receiptWrites: 20 } });
    expect(report.status).toBe('over-budget');
    expect(report.exceeded).toContain('writesDaily');
  });
  it('counts loaded-instance memory time, not process RSS or active CPU', () => {
    const report = evaluateFreeCapacity({ ...fixture, observations: { ...fixture.observations,
      monthlyInstanceMemoryGiBHours: 270 } });
    expect(report.status).toBe('over-budget');
    expect(report.exceeded).toContain('monthlyInstanceMemoryGiBHours');
  });
  it.each([NaN, -1, Infinity])('rejects invalid observations: %s', (value) => {
    expect(() => evaluateFreeCapacity({ ...fixture, observations: { ...fixture.observations,
      receiptReads: value } })).toThrow();
  });
});
