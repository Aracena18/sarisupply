import { initializeApp } from 'firebase-admin/app';

initializeApp();

export {
  reviewMerchantApplication,
  saveMerchantApplicationDraft,
  submitMerchantApplication,
} from './merchant/application-functions';
