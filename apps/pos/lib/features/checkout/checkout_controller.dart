import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import '../cashier_auth/domain/cashier_login_service.dart';

/// Owns one cashier's drafts, serializes edits and freezes payment before commit.
final class CheckoutController extends ChangeNotifier {
  CheckoutController(
      {required this.store,
      required this.session,
      required this.authorize,
      required this.inventoryGateway,
      required this.checkoutGateway,
      required this.grantResolver,
      this.onAccessDenied});
  final InventoryStore store;
  final CashierSession session;
  final Future<CheckoutAuthorization> Function() authorize;
  final InventoryGateway inventoryGateway;
  final CheckoutGateway checkoutGateway;
  final Future<IssuedCashierGrant?> Function(CheckoutScope) grantResolver;
  final Future<void> Function()? onAccessDenied;
  bool _requiresReconnect = false;
  CashierShift? shift;
  CheckoutDraft? draft;
  CheckoutSale? recovery;
  CheckoutAuthorization? authorization;
  List<InventoryRow> products = [];
  String? error, syncMessage, notice;
  bool noticeNeedsPriceReview = false;
  bool busy = false, syncing = false, allowed = false, _alive = true;
  Future<void> _edits = Future.value();
  Object? _saveError;
  String query = '';
  void changed() {
    if (_alive) notifyListeners();
  }

  Future<bool> revalidate() async {
    if (_requiresReconnect) {
      allowed = false;
      error = 'Reconnect and sign in to continue checkout';
      changed();
      return false;
    }
    try {
      final a = await authorize();
      if (!_alive ||
          _requiresReconnect ||
          a.scope.deviceId != session.deviceId ||
          a.scope.cashierId != session.cashierId ||
          a.scope.merchantId != store.merchantId ||
          a.scope.branchId != store.branchId) {
        throw StateError('Expired session');
      }
      authorization = a;
      allowed = true;
      error = null;
    } on Object {
      allowed = false;
      error = 'Reconnect and sign in to continue checkout';
    }
    changed();
    return allowed;
  }

  Future<void> load() async {
    await revalidate();
    shift = await store.checkout.activeShift(session.deviceId);
    draft = await store.checkout.readDraft(session.deviceId, session.cashierId);
    recovery =
        await store.checkout.unseenReceipt(session.deviceId, session.cashierId);
    await search('');
  }

  bool get ownsShift =>
      shift != null && shift!.scope.cashierId == session.cashierId;
  bool get editable =>
      _alive &&
      allowed &&
      ownsShift &&
      !busy &&
      draft?.frozenSale == null &&
      (draft?.paymentAttemptId.isEmpty ?? true);
  int get total => draft?.totalCentavos ?? 0;
  Future<void> search(String value) async {
    if (!_alive) return;
    query = value;
    try {
      final result = await store.search(value.trim());
      if (_alive && query == value) {
        products = result;
        changed();
      }
    } on Object {
      error = 'Products could not be loaded. Try again.';
      changed();
    }
  }

  void updateDraft(CheckoutDraft next) {
    draft = next;
    changed();
    _edits = _edits.then((_) async {
      try {
        await store.checkout.saveDraft(next);
        _saveError = null;
      } on Object catch (e) {
        _saveError = e;
        error = 'Cart could not be saved. Try again.';
        changed();
      }
    });
  }

  Future<void> flush() async {
    await _edits;
    if (_saveError != null) {
      final current = draft;
      if (current == null) throw StateError('Cart could not be saved');
      await store.checkout.saveDraft(current);
      _saveError = null;
    }
  }

  CheckoutDraft _cart(List<CartLine> lines) {
    final a = authorization!;
    final next =
        CheckoutDraft(scope: a.scope, shiftId: shift!.id, lines: lines);
    if (lines.isNotEmpty) {
      CheckoutSale(
          id: 'validation',
          scope: a.scope,
          shiftId: shift!.id,
          ordinal: shift!.lastOrdinal + 1,
          occurredAt: a.occurredAt,
          merchantName: a.merchantName,
          branchName: a.branchName,
          lines: lines,
          tender: Tender.cash(next.totalCentavos));
    }
    return draft == null ? next : draft!.copyWith(lines: lines);
  }

  String? takeNotice() {
    final value = notice;
    notice = null;
    return value;
  }

  void _notice(String message, {bool reviewPrices = false}) {
    notice = message;
    noticeNeedsPriceReview = reviewPrices;
    changed();
  }

  Future<void> _addFailure(Object failure) async {
    if (failure is FirebaseException) {
      if (['permission-denied', 'unauthenticated'].contains(failure.code)) {
        await _deny();
      } else {
        _notice(operationErrorMessage(failure));
      }
      return;
    }
    final reason = failure is StateError
        ? failure.message
        : failure is ArgumentError
            ? failure.message
            : null;
    if (reason == 'Quote changed' ||
        reason == 'Inconsistent product quote' ||
        reason == 'Inconsistent unit quote' ||
        reason == 'Quote changed; sync and review') {
      _notice(
          'This cart has older prices. Review prices, then add the item again.',
          reviewPrices: true);
    } else if (reason == 'Invalid receipt') {
      _notice(
          'Cart limit reached: 20 different products, 50 lines. Finish this sale or remove an item.');
    } else if (reason == 'Receipt is too large') {
      _notice(
          'Cart quantity or total exceeds the supported limit. Reduce the quantity or split this sale.');
    } else if (reason == 'Shift unavailable') {
      _notice('The shift changed. Lock and sign in again to reload checkout.');
    } else if (_saveError != null) {
      _notice('Cart could not be saved. Try again before taking payment.');
    } else {
      _notice('Could not add this item. Sync the catalog and try again.');
    }
  }

  Future<bool> add(CatalogProduct p, CatalogUnit unit) async {
    if (!editable) return false;
    final existing = draft?.lines ?? const <CartLine>[];
    final sameUnit =
        existing.any((l) => l.productId == p.id && l.unit == unit.name);
    if ((!existing.any((l) => l.productId == p.id) &&
            existing.map((l) => l.productId).toSet().length >= 20) ||
        (!sameUnit && existing.length >= 50)) {
      _notice(
          'Cart limit reached: 20 different products, 50 lines. Finish this sale or remove an item.');
      return false;
    }
    try {
      var sequence = await store.checkout.catalogSequence(p.id);
      if (sequence == null) {
        final resolved = await checkoutGateway
            .resolveQuotes(store.merchantId, store.branchId, [p]);
        await store.checkout.resolveQuote(resolved.single);
        sequence = resolved.single.sequence;
      }
      if (!editable) return false;
      final lines = [...?draft?.lines];
      final n =
          lines.indexWhere((l) => l.productId == p.id && l.unit == unit.name);
      if (n >= 0) {
        if (lines[n].catalogRevision != p.revision ||
            lines[n].catalogSequence != sequence) {
          throw StateError('Quote changed');
        }
        lines[n] = lines[n].withQuantity(lines[n].quantity + 1);
      } else {
        lines.add(CartLine(
            productId: p.id,
            sku: p.sku,
            name: p.name,
            unit: unit.name,
            factor: unit.factor,
            priceCentavos: unit.priceCentavos,
            quantity: 1,
            catalogSequence: sequence,
            catalogRevision: p.revision));
      }
      updateDraft(_cart(lines));
      await flush();
      error = null;
      changed();
      return true;
    } on Object catch (failure) {
      await _addFailure(failure);
      return false;
    }
  }

  Future<BarcodeMatch?> barcode(String code) async => store.lookupBarcode(code);
  Future<void> quantity(int index, int amount) async {
    if (!editable) return;
    try {
      final lines = [...draft!.lines];
      if (amount == 0) {
        lines.removeAt(index);
      } else {
        lines[index] = lines[index].withQuantity(amount);
      }
      updateDraft(_cart(lines));
      await flush();
      error = null;
      changed();
    } on Object {
      _notice('Check the quantity and cart limit.');
    }
  }

  Future<void> discard() async {
    if (!editable || draft == null) return;
    await flush();
    await store.checkout.discardDraft(session.deviceId, session.cashierId);
    draft = null;
    changed();
  }

  Future<List<CartLine>> currentPrices() async {
    final lines = <CartLine>[];
    for (final old in draft!.lines) {
      final row = (await store.search(old.sku))
          .where((r) => r.product.id == old.productId);
      if (row.isEmpty || !row.single.product.active) continue;
      final p = row.single.product;
      final units = p.units.where((u) => u.name == old.unit);
      if (units.isEmpty) continue;
      var sequence = await store.checkout.catalogSequence(p.id);
      if (sequence == null) {
        final quotes = await checkoutGateway
            .resolveQuotes(store.merchantId, store.branchId, [p]);
        await store.checkout.resolveQuote(quotes.single);
        sequence = quotes.single.sequence;
      }
      final u = units.single;
      lines.add(CartLine(
          productId: p.id,
          sku: p.sku,
          name: p.name,
          unit: u.name,
          factor: u.factor,
          priceCentavos: u.priceCentavos,
          quantity: old.quantity,
          catalogSequence: sequence,
          catalogRevision: p.revision));
    }
    return lines;
  }

  Future<void> applyPrices(List<CartLine> lines) async {
    if (editable) {
      updateDraft(_cart(lines));
      await flush();
      error = null;
      changed();
    }
  }

  Future<CheckoutSale> complete() async {
    if (busy) throw StateError('Payment is being saved');
    busy = true;
    changed();
    try {
      await flush();
      if (!await revalidate() || !ownsShift || draft == null) {
        throw StateError('Expired checkout');
      }
      var sale = draft!.frozenSale;
      if (sale == null) {
        var a = authorization!;
        var tender = draft!.tenderKind == 'cash'
            ? Tender.cash(parsePhpCentavos(draft!.received))
            : draft!.tenderKind == 'credit'
                ? Tender.credit(draft!.qrReference)
                : Tender.qr(draft!.qrReference, confirmed: draft!.qrConfirmed);
        final saleId = draft!.paymentAttemptId.isEmpty
            ? const Uuid().v4()
            : draft!.paymentAttemptId;
        if (tender.kind == 'credit' && draft!.paymentAttemptId.isEmpty) {
          final locked = draft!.copyWith(paymentAttemptId: saleId);
          await store.checkout.saveDraft(locked);
          draft = locked;
          changed();
        }
        if (tender.kind == 'credit') {
          var credit = await store.checkout
              .getCreditGrant(tender.reference, session.deviceId);
          if (credit == null || !credit.canChargeOffline(total, a.occurredAt)) {
            final cashierGrant = await grantResolver(a.scope);
            if (checkoutGateway is! CreditGateway || cashierGrant == null) {
              throw StateError('Connect to reserve credit');
            }
            credit = await (checkoutGateway as CreditGateway).reserveCredit(
                cashierGrant, tender.reference, total, 'credit-$saleId');
            await store.checkout.saveCreditGrant(credit, serverIssued: true);
          }
          if (!await revalidate() ||
              !ownsShift ||
              !a.scope.sameCashier(authorization!.scope)) {
            throw StateError('Expired checkout');
          }
          a = authorization!;
          if (!credit.canChargeOffline(total, a.occurredAt)) {
            throw StateError('Reserved credit needs review');
          }
          tender = Tender.credit(tender.reference, creditGrantId: credit.id);
        }
        sale = CheckoutSale(
            id: saleId,
            scope: a.scope,
            shiftId: shift!.id,
            ordinal: shift!.lastOrdinal + 1,
            occurredAt: a.occurredAt,
            merchantName: a.merchantName,
            branchName: a.branchName,
            lines: draft!.lines,
            tender: tender);
        final frozen = draft!.copyWith(scope: a.scope, frozenSale: sale);
        await store.checkout.saveDraft(frozen);
        draft = frozen;
        changed();
      }
      if (!await revalidate() ||
          !sale.scope.sameCashier(authorization!.scope)) {
        throw StateError('Expired checkout');
      }
      final saved = await store.checkout.completeSale(sale);
      draft = null;
      shift = await store.checkout.activeShift(session.deviceId);
      recovery = saved;
      changed();
      return saved;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> cancelCreditReservation() async {
    if (busy ||
        draft == null ||
        draft!.frozenSale != null ||
        draft!.paymentAttemptId.isEmpty) {
      return;
    }
    busy = true;
    changed();
    try {
      await flush();
      if (!await revalidate() || !ownsShift) {
        throw StateError('Expired checkout');
      }
      final grant = await grantResolver(authorization!.scope);
      if (grant == null || checkoutGateway is! CreditReservationRecovery) {
        throw StateError('Connect to cancel reserved credit');
      }
      final attemptId = draft!.paymentAttemptId;
      await (checkoutGateway as CreditReservationRecovery)
          .cancelReservation(grant, draft!.qrReference, 'credit-$attemptId');
      await store.checkout
          .cancelReservedDraft(session.deviceId, session.cashierId, attemptId);
      draft =
          await store.checkout.readDraft(session.deviceId, session.cashierId);
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> sync() async {
    if (syncing || busy) return;
    syncing = true;
    changed();
    try {
      await flush();
      // Cashier authority may pull but never upload human-only count drafts.
      final more =
          await InventorySync(store, inventoryGateway, canUpload: false).run();
      final pending = await CheckoutSync(store.checkout, checkoutGateway,
              grantResolver: grantResolver)
          .run();
      final rejected = await store.checkout.pendingIntents();
      if (rejected.any((i) =>
          i.status == 'blocked' &&
          i.scope.grantId == authorization?.scope.grantId &&
          i.message == 'Reconnect and review this receipt')) {
        await _deny();
        return;
      }
      syncMessage = more || pending ? 'Sync pending' : 'Up to date';
      await search(query);
    } on Object catch (error) {
      if (error is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(error.code)) {
        await _deny();
      }
      syncMessage = 'Sync pending · Try again when connected';
    } finally {
      syncing = false;
      changed();
    }
  }

  Future<void> _deny() async {
    _requiresReconnect = true;
    allowed = false;
    error = 'Reconnect and sign in to continue checkout';
    changed();
    await onAccessDenied?.call();
  }

  Future<void> mutation(String kind, int amount, String reason) async {
    if (busy) return;
    busy = true;
    changed();
    try {
      await flush();
      if (!await revalidate()) throw StateError('Expired checkout');
      final a = authorization!;
      final current = await store.checkout.activeShift(session.deviceId);
      if (kind == 'openShift') {
        final uuid = const Uuid().v4();
        await store.checkout.openShift(CheckoutIntent(
            id: uuid,
            scope: a.scope,
            shiftId: uuid,
            ordinal: 1,
            occurredAt: a.occurredAt,
            kind: kind,
            payload: {'floatCentavos': amount}));
      } else {
        if (current == null || !current.scope.sameCashier(a.scope)) {
          throw StateError('Cashier shift mismatch');
        }
        if (kind == 'closeShift' && draft != null && draft!.lines.isNotEmpty) {
          throw StateError('Finish or discard the cart first');
        }
        final op = CheckoutIntent(
            id: const Uuid().v4(),
            scope: a.scope,
            shiftId: current.id,
            ordinal: current.lastOrdinal + 1,
            occurredAt: a.occurredAt,
            kind: kind,
            payload: kind == 'closeShift'
                ? {'countedCentavos': amount, 'reason': reason}
                : {'amountCentavos': amount, 'reason': reason});
        if (kind == 'closeShift') {
          await store.checkout.closeShift(op);
        } else {
          await store.checkout.recordCashMovement(op);
        }
      }
      shift = await store.checkout.activeShift(session.deviceId);
      changed();
    } finally {
      busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _alive = false;
    unawaited(_edits.then((_) => store.close()));
    super.dispose();
  }
}
