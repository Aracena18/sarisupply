import { describe, expect, it } from 'vitest';
import { nextApplicationStatus } from '../../src/merchant/application-state';

describe('merchant application state', () => {
  it('moves a new draft through submission and review', () => {
    const draft = nextApplicationStatus(undefined, 'saveDraft');
    const submitted = nextApplicationStatus(draft, 'submit');
    const pending = nextApplicationStatus(submitted, 'queueReview');
    expect(draft).toBe('draft');
    expect(submitted).toBe('submitted');
    expect(pending).toBe('pending_review');
    expect(nextApplicationStatus(pending, 'approve')).toBe('approved');
  });

  it('allows a rejected applicant to revise and resubmit', () => {
    const rejected = nextApplicationStatus('pending_review', 'reject');
    expect(nextApplicationStatus(rejected, 'saveDraft')).toBe('rejected');
    expect(nextApplicationStatus(rejected, 'submit')).toBe('resubmitted');
    expect(nextApplicationStatus('resubmitted', 'queueReview'))
      .toBe('pending_review');
  });

  it('never reopens an approved application', () => {
    expect(() => nextApplicationStatus('approved', 'saveDraft')).toThrow();
    expect(() => nextApplicationStatus('approved', 'submit')).toThrow();
  });
});
