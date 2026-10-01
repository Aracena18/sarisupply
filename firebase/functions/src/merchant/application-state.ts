import { HttpsError } from 'firebase-functions/v2/https';

export type ApplicationStatus =
  | 'draft'
  | 'submitted'
  | 'resubmitted'
  | 'pending_review'
  | 'approved'
  | 'rejected';

export type ApplicationAction =
  | 'saveDraft'
  | 'submit'
  | 'queueReview'
  | 'approve'
  | 'reject';

export function nextApplicationStatus(
  current: ApplicationStatus | undefined,
  action: ApplicationAction,
): ApplicationStatus {
  if (action === 'saveDraft' && current === undefined) return 'draft';
  if (action === 'saveDraft' && (current === 'draft' || current === 'rejected')) {
    return current;
  }
  if (action === 'submit' && current === 'draft') return 'submitted';
  if (action === 'submit' && current === 'rejected') return 'resubmitted';
  if (action === 'queueReview' &&
      (current === 'submitted' || current === 'resubmitted')) {
    return 'pending_review';
  }
  if (action === 'approve' && current === 'pending_review') return 'approved';
  if (action === 'reject' && current === 'pending_review') return 'rejected';
  throw new HttpsError('failed-precondition', 'Invalid application transition');
}
