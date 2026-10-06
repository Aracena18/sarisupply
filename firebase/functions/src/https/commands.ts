import { readOperationalWorkspace } from '../management/operations-read-service';
import { manageCustomers } from '../checkout/customer-service';
import { recordCheckoutOperation, resolveCatalogQuotes, approveCheckoutReversal } from '../checkout/checkout-service';
import { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthRequest, requireHuman } from '../common/authz';
import * as application from '../merchant/application-service';
import * as membership from '../membership/membership-service';
import * as device from '../device/device-service';
import * as cashier from '../cashier/cashier-service';
import { createPinHasher } from '../cashier/pin-kdf';
import { saveCatalogProduct, recordStockCount, pullInventory } from '../catalog/catalog-service';
import { recordReceiving, recordStockAdjustment } from '../catalog/receiving-service';
import { initiateBranchTransfer, receiveBranchTransfer, readIncomingTransfers } from '../catalog/transfer-service';
import { listManagementRecords } from '../management/workspace-service';
import { manageSuppliers, managePurchaseOrders, manageRestockProposals, readProcurementWorkspace, manageWarehouses } from '../procurement/procurement-service';
import { manageDeliveries, getDriverWorkspaces } from '../delivery/delivery-service';

type Command = (identity: AuthRequest, data: Record<string, unknown>) => Promise<unknown>;

// Casts match the existing callable adapters. Domain services validate all input
// and derive authority from the verified identity and current Firestore state.
export function createCommandDispatcher(
  db: Firestore, mintToken: device.MintDeviceToken, hasher: ReturnType<typeof createPinHasher>,
) {
  const commands: Record<string, Command> = {
    readOperationalWorkspace: (r,d) => readOperationalWorkspace(db,r,d),
    manageCustomers: (r,d) => manageCustomers(db,r,d),
    recordCheckoutOperation: (r,d) => recordCheckoutOperation(db,r,d),
    approveCheckoutReversal: (r,d) => approveCheckoutReversal(db,r,d),
    resolveCatalogQuotes: (r,d) => resolveCatalogQuotes(db,r,d),
    saveCatalogProduct: (r, d) => saveCatalogProduct(db, r, d),
    recordStockCount: (r, d) => recordStockCount(db, r, d),
    pullInventory: (r, d) => pullInventory(db, r, d),
    recordReceiving: (r, d) => recordReceiving(db, r, d),
    recordStockAdjustment: (r, d) => recordStockAdjustment(db, r, d),
    initiateBranchTransfer: (r, d) => initiateBranchTransfer(db, r, d),
    receiveBranchTransfer: (r, d) => receiveBranchTransfer(db, r, d),
    readIncomingTransfers: (r,d) => readIncomingTransfers(db,r,d),
    manageSuppliers: (r, d) => manageSuppliers(db, r, d),
    managePurchaseOrders: (r, d) => managePurchaseOrders(db, r, d),
    manageRestockProposals: (r, d) => manageRestockProposals(db, r, d),
    readProcurementWorkspace: (r, d) => readProcurementWorkspace(db, r, d),
    manageWarehouses: (r, d) => manageWarehouses(db, r, d),
    manageDeliveries: (r, d) => manageDeliveries(db, r, d),
    getDriverWorkspaces: (r) => getDriverWorkspaces(db, r),
    listManagementRecords: (r, d) => listManagementRecords(db, r, { merchantId: d.merchantId, kind: d.kind, cursor: d.cursor }),
    saveMerchantApplicationDraft: (r, d) => application.saveMerchantApplicationDraft(db, requireHuman(r), d as unknown as application.DraftInput),
    submitMerchantApplication: (r, d) => application.submitMerchantApplication(db, requireHuman(r), d.applicationId as string),
    reviewMerchantApplication: (r, d) => application.reviewMerchantApplication(db, r, d as unknown as application.ReviewInput),
    createManagerInvitation: (r, d) => membership.createManagerInvitation(db, r, d as unknown as Parameters<typeof membership.createManagerInvitation>[2]),
    listMyInvitations: async (r) => ({ invitations: await membership.listMyInvitations(db, r) }),
    acceptManagerInvitation: (r, d) => membership.acceptManagerInvitation(db, r, d.merchantId as string, d.inviteId as string),
    revokeManagerInvitation: async (r, d) => {
      await membership.revokeManagerInvitation(db, r, d.merchantId as string, d.inviteId as string);
      return { status: 'revoked' };
    },
    updateManagerAccess: async (r, d) => {
      await membership.updateManagerAccess(db, r, d.merchantId as string, d.managerUid as string, d.allBranches as boolean, d.branchIds as string[]);
      return { status: 'updated' };
    },
    removeManager: async (r, d) => {
      await membership.removeManager(db, r, d.merchantId as string, d.managerUid as string);
      return { status: 'removed' };
    },
    createBranch: (r, d) => membership.createBranch(db, r, d as unknown as Parameters<typeof membership.createBranch>[2]),
    deactivateBranch: async (r, d) => {
      await membership.deactivateBranch(db, r, d.merchantId as string, d.branchId as string);
      return { status: 'inactive' };
    },
    activatePosDevice: (r, d) => device.activatePosDevice(db, mintToken, r, d as unknown as device.ActivateDeviceInput),
    getDeviceBootstrap: (r) => device.getDeviceBootstrap(db, r),
    revokePosDevice: async (r, d) => {
      await device.revokePosDevice(db, r, d.merchantId as string, d.deviceId as string);
      return { status: 'revoked' };
    },
    createCashier: (r, d) => cashier.createCashier(db, hasher, r, d as unknown as Parameters<typeof cashier.createCashier>[3]),
    setCashierStatus: async (r, d) => {
      await cashier.setCashierStatus(db, r, d.merchantId as string, d.cashierId as string, d.status as 'active' | 'suspended');
      return { status: d.status };
    },
    verifyCashierPin: (r, d) => cashier.verifyCashierPin(db, hasher, r, d.cashierId as string, d.pin as string),
    changeCashierPin: (r, d) => cashier.changeCashierPin(db, hasher, r, d.cashierId as string, d.currentPin as string, d.newPin as string),
    resetCashierPin: (r, d) => cashier.resetCashierPin(db, hasher, r, d.merchantId as string, d.cashierId as string),
    refreshCashierCredentialBundle: (r) => cashier.refreshCashierCredentialBundle(db, r),
    reportOfflinePinFailures: (r, d) => cashier.reportOfflinePinFailures(db, r, d.events),
  };
  const hasCommand = (name: string) => Object.hasOwn(commands, name);
  return {
    hasCommand,
    async dispatch(name: string, identity: AuthRequest, data: Record<string, unknown>) {
      if (!hasCommand(name)) throw new HttpsError('not-found', 'Unknown command');
      return commands[name](identity, data);
    },
  };
}
