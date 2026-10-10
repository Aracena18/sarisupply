import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

/// Focused order sheet; the caller retains all command authorization.
class CompanyOrderDetails extends StatelessWidget {
  const CompanyOrderDetails({
    super.key,
    required this.order,
    required this.storeName,
    required this.statusLabel,
    required this.totalCentavos,
    required this.balanceCentavos,
    required this.actionsEnabled,
    required this.onAction,
    required this.onResolveReceipt,
    required this.onClose,
    this.cached = false,
  });

  final CompanyRecord order;
  final String storeName, statusLabel;
  final int totalCentavos, balanceCentavos;
  final bool actionsEnabled, cached;
  final ValueChanged<String> onAction;
  final VoidCallback onResolveReceipt, onClose;

  String _money(int cents) =>
      '₱${(cents.abs() ~/ 100)}.${(cents.abs() % 100).toString().padLeft(2, '0')}';

  String get _nextStep => switch (order.status) {
    'submitted' => 'Accept to reserve stock.',
    'accepted' => 'Pick the accepted items.',
    'picking' => 'Pack all accepted quantities.',
    'awaitingConfirmation' => 'Waiting for store approval.',
    'packed' => 'Continue from Deliveries.',
    'dispatched' || 'inTransit' => 'Track this order in Deliveries.',
    'completed' => 'Store receipt confirmed.',
    'cancelled' => 'Order cancelled.',
    'rejected' => 'Order rejected.',
    _ => '',
  };

  String? get _primaryAction => switch (order.status) {
    'submitted' => 'acceptOrder',
    'accepted' => 'startPicking',
    'picking' => 'packOrder',
    _ => null,
  };

  String get _primaryLabel => switch (_primaryAction) {
    'acceptOrder' => 'Accept order',
    'startPicking' => 'Start picking',
    'packOrder' => 'Confirm packing',
    _ => '',
  };

  Widget _itemRows(List<Map<String, Object?>> lines) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final line in lines) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${line['name']}',
                      style: SariSupplyTypography.cardHeading,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${line['quantity']} ${line['unit']} × '
                      '${_money(line['priceCentavos'] as int)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _money(
                  (line['quantity'] as int) * (line['priceCentavos'] as int),
                ),
                style: SariSupplyTypography.label,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    ],
  );

  List<PopupMenuEntry<String>> _moreActions() {
    final actions = <PopupMenuEntry<String>>[];
    if (order.status == 'submitted' || order.status == 'picking') {
      actions.add(
        const PopupMenuItem(
          value: 'proposeOrder',
          child: Text('Propose item changes'),
        ),
      );
    }
    if (order.status == 'submitted') {
      actions.add(
        const PopupMenuItem(value: 'rejectOrder', child: Text('Reject order')),
      );
    }
    if (!const {'cancelled', 'rejected'}.contains(order.status) &&
        balanceCentavos > 0 &&
        (order.string('paymentMethod').isEmpty ||
            order.string('paymentMethod') == 'qr')) {
      actions.add(
        const PopupMenuItem(
          value: 'confirmQr',
          child: Text('Confirm QR payment'),
        ),
      );
    }
    if (order.string('receiptStatus') == 'needsReview') {
      actions.add(
        const PopupMenuItem(
          value: 'resolveReceipt',
          child: Text('Resolve receipt difference'),
        ),
      );
    }
    if (order.string('status') == 'awaitingConfirmation' || actions.isEmpty) {
      return const [];
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final items = order.records('lines');
    final proposed = order.records('proposedLines');
    final actions = actionsEnabled
        ? _moreActions()
        : const <PopupMenuEntry<String>>[];
    final evidence = order.data['deliveryEvidence'];
    final delivery = [
      order.string('address'),
      order.string('contact'),
      order.string('phone'),
      if (order.string('notes').isNotEmpty) 'Note: ${order.string('notes')}',
    ].where((value) => value.isNotEmpty).toList();

    return Material(
      color: SariSupplyColors.paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(storeName, style: SariSupplyTypography.screenTitle),
                      const SizedBox(height: 4),
                      Text(
                        '$statusLabel · ${_money(totalCentavos)}',
                        style: SariSupplyTypography.body.copyWith(
                          color: SariSupplyColors.ink600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty)
                  PopupMenuButton<String>(
                    tooltip: 'More order actions',
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (_) => actions,
                    onSelected: (action) {
                      Navigator.of(context).pop();
                      if (action == 'resolveReceipt') {
                        onResolveReceipt();
                      } else {
                        onAction(action);
                      }
                    },
                  ),
                IconButton(
                  tooltip: 'Close order details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                if (_nextStep.isNotEmpty)
                  Text(_nextStep, style: SariSupplyTypography.body),
                if (cached)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Offline view · Refresh before processing.',
                      style: SariSupplyTypography.caption,
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Items (${items.length})',
                  style: SariSupplyTypography.sectionHeading,
                ),
                const SizedBox(height: 4),
                _itemRows(items),
                if (order.status == 'awaitingConfirmation' &&
                    proposed.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Proposed items · awaiting approval',
                    style: SariSupplyTypography.sectionHeading,
                  ),
                  if (order.string('changeReason').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(order.string('changeReason')),
                    ),
                  _itemRows(proposed),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order total'),
                      Text(
                        _money(totalCentavos),
                        style: SariSupplyTypography.cardHeading,
                      ),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Delivery & payment'),
                    childrenPadding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final detail in delivery)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(detail),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          order.string('paymentMethod') == 'qr'
                              ? order.number('paymentConfirmedCentavos') == 0
                                    ? 'QR payment · awaiting supplier confirmation'
                                    : 'QR payment · ${_money(order.number('paymentConfirmedCentavos'))} confirmed'
                              : 'Cash on delivery · collect payment at delivery',
                        ),
                      ),
                      if (order.string('paymentMethod') == 'qr')
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('QR balance ${_money(balanceCentavos)}'),
                        ),
                      if (evidence is Map)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Receipt: ${order.string('receiptStatus').isEmpty ? 'awaiting review' : order.string('receiptStatus')}',
                            ),
                          ),
                        ),
                      if (order.string('resolutionNote').isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(order.string('resolutionNote')),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Order ID · ${order.id}',
                            style: SariSupplyTypography.caption,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_primaryAction case final action?)
                    FilledButton(
                      onPressed: actionsEnabled
                          ? () {
                              Navigator.of(context).pop();
                              onAction(action);
                            }
                          : null,
                      child: Text(_primaryLabel),
                    ),
                  if (_primaryAction == null)
                    OutlinedButton(
                      onPressed: onClose,
                      child: const Text('Done'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
