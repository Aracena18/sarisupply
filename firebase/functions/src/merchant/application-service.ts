import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { writeAuditEvent } from '../common/audit';
import { AuthorizationService, requireHuman } from '../common/authz';
import type { AuthRequest } from '../common/authz';
import { runIdempotent } from '../common/idempotency';
import { requireDocumentId } from '../common/ids';
import { nextApplicationStatus } from './application-state';
import type { ApplicationStatus } from './application-state';

export interface DraftInput {
  applicationId?: string;
  businessProfile: Record<string, unknown>;
  firstBranchDraft: Record<string, unknown>;
}

export interface ReviewInput {
  applicationId: string;
  decision: 'approve' | 'reject';
  operationId: string;
  companyId?: string;
  reviewNotes?: string;
}

export interface ReviewResult {
  applicationId: string;
  status: 'approved' | 'rejected';
  merchantId?: string;
  branchId?: string;
}

function transactionalAuthorization(
  db: Firestore,
  transaction: Transaction,
): AuthorizationService {
  return new AuthorizationService(async (path) => {
    const snapshot = await transaction.get(db.doc(path));
    return snapshot.exists ? snapshot.data() ?? null : null;
  });
}

function applicationTimestamp(value: unknown): string | null {
  return value instanceof Timestamp ? value.toDate().toISOString() : null;
}

/** Company Owners may inspect only the submitted application fields. */
export async function listPendingMerchantApplications(
  db: Firestore,
  request: AuthRequest,
  inputCompanyId: string,
): Promise<{ applications: Array<Record<string, unknown>> }> {
  const companyId = requireDocumentId(inputCompanyId, 'company ID');
  return db.runTransaction(async (transaction) => {
    await transactionalAuthorization(db, transaction)
      .requireCompanyRole(request, companyId, 'companyOwner');
    const pending = await transaction.get(
      db.collection('merchantApplications')
        .where('status', '==', 'pending_review')
        .orderBy('submittedAt', 'desc'),
    );
    return {
      applications: pending.docs.map((document) => {
        const data = document.data();
        return {
          id: document.id,
          applicantUid: data.applicantUid,
          status: data.status,
          businessProfile: data.businessProfile,
          firstBranchDraft: data.firstBranchDraft,
          submittedAt: applicationTimestamp(data.submittedAt),
          reviewedAt: applicationTimestamp(data.reviewedAt),
          reviewedBy: data.reviewedBy ?? null,
          reviewNotes: data.reviewNotes ?? null,
          approvedMerchantId: data.approvedMerchantId ?? null,
        };
      }),
    };
  });
}

function requireObject(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', `${field} must be an object`);
  }
  return value as Record<string, unknown>;
}

function requiredText(value: unknown, field: string): string {
  if (typeof value !== 'string' || !value.trim() || value.length > 300) {
    throw new HttpsError('invalid-argument', `Invalid ${field}`);
  }
  return value.trim();
}

function validateSubmission(
  businessProfile: Record<string, unknown>,
  firstBranchDraft: Record<string, unknown>,
): void {
  requiredText(businessProfile.name, 'business name');
  requiredText(firstBranchDraft.name, 'branch name');
  requiredText(firstBranchDraft.code, 'branch code');
  requiredText(firstBranchDraft.address, 'branch address');
}

function requireApplicant(
  data: Record<string, unknown> | undefined,
  uid: string,
): ApplicationStatus {
  if (data?.applicantUid !== uid) {
    throw new HttpsError('permission-denied', 'Application access denied');
  }
  return data.status as ApplicationStatus;
}

export async function saveMerchantApplicationDraft(
  db: Firestore,
  uid: string,
  input: DraftInput,
): Promise<{ applicationId: string; status: ApplicationStatus }> {
  requireDocumentId(uid, 'user ID');
  const businessProfile = requireObject(input.businessProfile, 'businessProfile');
  const firstBranchDraft = requireObject(input.firstBranchDraft, 'firstBranchDraft');
  const applicationId = input.applicationId === undefined
    ? db.collection('merchantApplications').doc().id
    : requireDocumentId(input.applicationId, 'application ID');
  const ref = db.doc(`merchantApplications/${applicationId}`);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (snapshot.exists) {
      const status = requireApplicant(snapshot.data(), uid);
      const nextStatus = nextApplicationStatus(status, 'saveDraft');
      transaction.update(ref, {
        businessProfile,
        firstBranchDraft,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return { applicationId, status: nextStatus };
    }
    if (input.applicationId !== undefined) {
      throw new HttpsError('not-found', 'Application not found');
    }
    const status = nextApplicationStatus(undefined, 'saveDraft');
    transaction.create(ref, {
      applicantUid: uid,
      status,
      businessProfile,
      firstBranchDraft,
      submittedAt: null,
      reviewedAt: null,
      reviewedBy: null,
      reviewNotes: null,
      approvedMerchantId: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { applicationId, status };
  });
}

export async function submitMerchantApplication(
  db: Firestore,
  uid: string,
  applicationId: string,
): Promise<{ applicationId: string; status: 'pending_review' }> {
  requireDocumentId(uid, 'user ID');
  requireDocumentId(applicationId, 'application ID');
  const ref = db.doc(`merchantApplications/${applicationId}`);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data();
    const status = requireApplicant(data, uid);
    const businessProfile = requireObject(data?.businessProfile, 'businessProfile');
    const firstBranchDraft = requireObject(data?.firstBranchDraft, 'firstBranchDraft');
    validateSubmission(businessProfile, firstBranchDraft);
    const submitted = nextApplicationStatus(status, 'submit');
    const pending = nextApplicationStatus(submitted, 'queueReview');
    if (pending !== 'pending_review') throw new Error('Invalid review queue state');
    transaction.update(ref, {
      status: pending,
      submittedAt: FieldValue.serverTimestamp(),
      reviewedAt: null,
      reviewedBy: null,
      reviewNotes: null,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { applicationId, status: pending };
  });
}

export async function reviewMerchantApplication(
  db: Firestore,
  request: AuthRequest,
  input: ReviewInput,
): Promise<ReviewResult> {
  const applicationId = requireDocumentId(input.applicationId, 'application ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  if (input.decision !== 'approve' && input.decision !== 'reject') {
    throw new HttpsError('invalid-argument', 'Invalid review decision');
  }
  const companyId = input.companyId === undefined
    ? undefined
    : requireDocumentId(input.companyId, 'company ID');
  const authorization = new AuthorizationService(async (path) => {
    const snapshot = await db.doc(path).get();
    return snapshot.exists ? snapshot.data() ?? null : null;
  });
  let companyReviewerUid: string | undefined;
  let adminUid: string | undefined;
  if (companyId !== undefined) {
    await authorization.requireCompanyRole(request, companyId, 'companyOwner');
    companyReviewerUid = requireHuman(request);
  } else {
    adminUid = await authorization.requirePlatformAdmin(request);
  }
  const applicationRef = db.doc(`merchantApplications/${applicationId}`);
  const adminRef = adminUid === undefined
    ? undefined
    : db.doc(`platformAdmins/${adminUid}`);

  return runIdempotent(`application-review:${applicationId}:${operationId}`,
    async (transaction) => {
      const transactionAuthorization = transactionalAuthorization(db, transaction);
      let reviewerUid: string;
      let reviewerType: 'companyOwner' | 'platformAdmin';
      if (companyId !== undefined) {
        await transactionAuthorization.requireCompanyRole(
          request,
          companyId,
          'companyOwner',
        );
        if (companyReviewerUid === undefined) {
          throw new HttpsError('internal', 'Company reviewer identity is missing');
        }
        reviewerUid = companyReviewerUid;
        reviewerType = 'companyOwner';
      } else {
        if (adminUid === undefined || adminRef === undefined) {
          throw new HttpsError('internal', 'Platform reviewer identity is missing');
        }
        reviewerUid = adminUid;
        reviewerType = 'platformAdmin';
        const admin = await transaction.get(adminRef);
        if (admin.data()?.status !== 'active') {
          throw new HttpsError('permission-denied', 'Admin access denied');
        }
      }
      const application = await transaction.get(applicationRef);
      const data = application.data();
      if (!data) throw new HttpsError('not-found', 'Application not found');
      if (data.status === 'approved' && input.decision === 'approve') {
        return {
          applicationId,
          status: 'approved' as const,
          merchantId: data.approvedMerchantId as string,
          branchId: data.approvedBranchId as string,
        };
      }
      if (data.status === 'rejected' && input.decision === 'reject') {
        return { applicationId, status: 'rejected' as const };
      }
      const status = nextApplicationStatus(data.status as ApplicationStatus,
        input.decision === 'approve' ? 'approve' : 'reject');
      if (status !== 'approved' && status !== 'rejected') {
        throw new Error('Invalid review state');
      }

      if (status === 'rejected') {
        const reviewNotes = requiredText(input.reviewNotes, 'review notes');
        transaction.update(applicationRef, {
          status,
          reviewedAt: FieldValue.serverTimestamp(),
          reviewedBy: reviewerUid,
          reviewNotes,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.create(db.collection('applicationAuditEvents').doc(), {
          applicationId,
          actorUid: reviewerUid,
          actorRole: reviewerType,
          ...(companyId === undefined ? {} : { companyId }),
          action: 'merchantApplication.rejected',
          createdAt: FieldValue.serverTimestamp(),
        });
        return { applicationId, status };
      }

      const applicantUid = requireDocumentId(data.applicantUid, 'applicant UID');
      const businessProfile = requireObject(data.businessProfile, 'businessProfile');
      const firstBranchDraft = requireObject(data.firstBranchDraft, 'firstBranchDraft');
      validateSubmission(businessProfile, firstBranchDraft);

      const merchantRef = db.collection('merchants').doc();
      const branchRef = merchantRef.collection('branches').doc();
      const now = FieldValue.serverTimestamp();
      transaction.create(merchantRef, {
        status: 'active',
        businessProfile,
        sourceApplicationId: applicationId,
        createdAt: now,
        createdBy: reviewerUid,
        updatedAt: now,
      });
      transaction.create(branchRef, {
        merchantId: merchantRef.id,
        name: requiredText(firstBranchDraft.name, 'branch name'),
        code: requiredText(firstBranchDraft.code, 'branch code'),
        address: requiredText(firstBranchDraft.address, 'branch address'),
        contactDetails: firstBranchDraft.contactDetails ?? {},
        operatingHours: firstBranchDraft.operatingHours ?? {},
        status: 'active',
        createdAt: now,
        createdBy: reviewerUid,
        updatedAt: now,
      });
      transaction.create(merchantRef.collection('memberships').doc(applicantUid), {
        userId: applicantUid,
        merchantId: merchantRef.id,
        role: 'owner',
        status: 'active',
        allBranches: true,
        branchIds: [],
        createdAt: now,
        createdBy: reviewerUid,
        updatedAt: now,
      });
      transaction.create(
        db.doc(`users/${applicantUid}/merchantRefs/${merchantRef.id}`), {
          merchantId: merchantRef.id,
          role: 'owner',
          status: 'active',
          updatedAt: now,
        },
      );
      transaction.update(applicationRef, {
        status,
        reviewedAt: now,
        reviewedBy: reviewerUid,
        reviewNotes: input.reviewNotes?.trim() || null,
        approvedMerchantId: merchantRef.id,
        approvedBranchId: branchRef.id,
        updatedAt: now,
      });
      await writeAuditEvent({
        merchantId: merchantRef.id,
        actorType: reviewerType,
        actorId: reviewerUid,
        action: 'merchant.approved',
        targetType: 'merchant',
        targetId: merchantRef.id,
        operationId,
        details: {
          applicationId,
          applicantUid,
          ...(companyId === undefined ? {} : { companyId }),
        },
      }, transaction, db);
      return {
        applicationId,
        status,
        merchantId: merchantRef.id,
        branchId: branchRef.id,
      };
    }, db);
}
