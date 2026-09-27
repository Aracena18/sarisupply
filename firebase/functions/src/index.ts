import { initializeApp } from 'firebase-admin/app';

initializeApp();

export {
  reviewMerchantApplication,
  saveMerchantApplicationDraft,
  submitMerchantApplication,
} from './merchant/application-functions';
export {
  acceptManagerInvitation,
  createManagerInvitation,
  listMyInvitations,
  removeManager,
  revokeManagerInvitation,
  updateManagerAccess,
} from './membership/invitation-functions';
export { createBranch, deactivateBranch } from './membership/branch-functions';
export {
  activatePosDevice,
  getDeviceBootstrap,
  revokePosDevice,
} from './device/device-functions';
