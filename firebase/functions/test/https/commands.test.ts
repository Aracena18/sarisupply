import { describe, expect, it } from 'vitest';
import { createCommandDispatcher } from '../../src/https/commands';

describe('HTTPS command registry', () => {
  it('exposes every current command and no inherited object properties', () => {
    const commands = createCommandDispatcher({} as never, {} as never, {} as never);
    for (const name of ['saveCatalogProduct', 'recordStockCount', 'pullInventory', 'listManagementRecords', 'reviewMerchantApplication', 'saveMerchantApplicationDraft',
      'submitMerchantApplication', 'acceptManagerInvitation', 'createManagerInvitation',
      'listMyInvitations', 'removeManager', 'revokeManagerInvitation', 'updateManagerAccess',
      'createBranch', 'deactivateBranch', 'activatePosDevice', 'getDeviceBootstrap',
      'revokePosDevice', 'changeCashierPin', 'createCashier', 'refreshCashierCredentialBundle',
      'reportOfflinePinFailures', 'resetCashierPin', 'setCashierStatus', 'verifyCashierPin']) {
      expect(commands.hasCommand(name), name).toBe(true);
    }
    expect(commands.hasCommand('constructor')).toBe(false);
    expect(commands.hasCommand('toString')).toBe(false);
    expect(commands.hasCommand('unknown')).toBe(false);
  });
  it('fails unauthenticated domain requests before any database access', async () => {
    const commands = createCommandDispatcher({} as never, {} as never, {} as never);
    await expect(commands.dispatch('saveMerchantApplicationDraft', {}, {}))
      .rejects.toMatchObject({ code: 'unauthenticated' });
    await expect(commands.dispatch('unknown', {}, {}))
      .rejects.toMatchObject({ code: 'not-found' });
  });
});
