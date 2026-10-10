import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

enum CompanyOrderQueueTab {
  awaiting('Awaiting'),
  accepted('Accepted'),
  ready('Ready'),
  onRoute('On route'),
  completed('Received');

  const CompanyOrderQueueTab(this.label);

  final String label;
}

/// Maps presentation groups to existing order and receipt facts.
///
/// The domain does not have a separate "ready" or "completed" order state.
/// Store receipt is the completion signal; payment remains independent.
CompanyOrderQueueTab? companyOrderQueueTab(CompanyRecord order) {
  if (order.status == 'cancelled' || order.status == 'rejected') return null;

  if (order.status == 'completed' ||
      const {'confirmed', 'resolved'}.contains(order.string('receiptStatus'))) {
    return CompanyOrderQueueTab.completed;
  }

  return switch (order.status) {
    'submitted' || 'awaitingConfirmation' => CompanyOrderQueueTab.awaiting,
    'accepted' || 'picking' => CompanyOrderQueueTab.accepted,
    'packed' => CompanyOrderQueueTab.ready,
    'dispatched' || 'inTransit' => CompanyOrderQueueTab.onRoute,
    _ => null,
  };
}

bool companyOrderMatchesSearch(CompanyRecord order, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return [
    order.id,
    order.string('storeName'),
    order.string('branchName'),
    order.string('address'),
  ].any((value) => value.toLowerCase().contains(normalized));
}

class CompanyOrderQueueRow extends StatelessWidget {
  const CompanyOrderQueueRow({
    super.key,
    required this.order,
    required this.storeName,
    required this.orderTime,
    required this.amount,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBackgroundColor,
    this.details = const SizedBox.shrink(),
    this.onOpenDetails,
    this.absorbing = false,
  });

  final CompanyRecord order;
  final String storeName;
  final String orderTime, amount, statusLabel;
  final Color statusColor, statusBackgroundColor;
  final Widget details;
  final VoidCallback? onOpenDetails;
  final bool absorbing;

  Widget _summary() => Semantics(
    button: onOpenDetails != null,
    label: 'Order from $storeName, ${order.id}, $amount, $statusLabel',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final reference = order.id.length > 8
            ? order.id.substring(order.id.length - 8)
            : order.id;
        final status = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusBackgroundColor,
            borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
          ),
          child: Text(
            statusLabel,
            style: SariSupplyTypography.caption.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        final items = Text(
          '${order.records('lines').length} '
          '${order.records('lines').length == 1 ? 'item' : 'items'}',
          style: SariSupplyTypography.caption.copyWith(
            color: SariSupplyColors.ink600,
          ),
        );
        final moneyStyle = SariSupplyTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        );
        final money = Text(amount, softWrap: false, style: moneyStyle);
        final moneyMeasurement = TextPainter(
          text: TextSpan(text: amount, style: moneyStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final stack =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20 ||
            moneyMeasurement.width > constraints.maxWidth / 2;
        moneyMeasurement.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: SariSupplyTypography.cardHeading,
                  ),
                ),
                if (onOpenDetails != null)
                  const Icon(
                    Icons.chevron_right,
                    color: SariSupplyColors.ink600,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  '#$reference',
                  style: SariSupplyTypography.caption.copyWith(
                    color: SariSupplyColors.ink600,
                  ),
                ),
                if (orderTime.isNotEmpty)
                  Text(
                    orderTime,
                    style: SariSupplyTypography.caption.copyWith(
                      color: SariSupplyColors.ink600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (stack) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [status, items],
              ),
              const SizedBox(height: 4),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: money,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [status, items],
                    ),
                  ),
                  const SizedBox(width: 8),
                  money,
                ],
              ),
          ],
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    absorbing: absorbing,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onOpenDetails case final onOpen?)
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: SariSupplySpacing.sm,
                horizontal: SariSupplySpacing.xs,
              ),
              child: _summary(),
            ),
          )
        else
          ExpansionTile(
            key: PageStorageKey('order:${order.id}'),
            tilePadding: const EdgeInsets.symmetric(
              vertical: SariSupplySpacing.sm,
            ),
            title: _summary(),
            children: [details],
          ),
        const Divider(height: 1),
      ],
    ),
  );
}

/// Centered empty content for a queue's remaining viewport.
class CompanyOrderQueueEmptyState extends StatelessWidget {
  const CompanyOrderQueueEmptyState({
    super.key,
    required this.message,
    required this.explanation,
    this.action,
  });

  final String message, explanation;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SariSupplySpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 36,
              color: SariSupplyColors.ink300,
            ),
            const SizedBox(height: SariSupplySpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: SariSupplyTypography.cardHeading,
            ),
            const SizedBox(height: SariSupplySpacing.xs),
            Text(
              explanation,
              textAlign: TextAlign.center,
              style: SariSupplyTypography.body.copyWith(
                color: SariSupplyColors.ink600,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: SariSupplySpacing.md),
              action!,
            ],
          ],
        ),
      ),
    ),
  );
}
