import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

enum CompanyDeliveryQueue { drafts, onRoute, history }

/// A rider assignment does not dispatch a draft or move warehouse stock.
CompanyDeliveryQueue companyDeliveryQueue(CompanyRecord run) =>
    switch (run.status) {
      'draft' => CompanyDeliveryQueue.drafts,
      'completed' || 'cancelled' => CompanyDeliveryQueue.history,
      _ => CompanyDeliveryQueue.onRoute,
    };

class CompanyDeliveryQueueRow extends StatelessWidget {
  const CompanyDeliveryQueueRow({
    super.key,
    required this.run,
    required this.destination,
    required this.orderCount,
    required this.statusLabel,
    required this.statusKind,
    required this.expanded,
    required this.onToggle,
    required this.details,
    this.recordedAt,
    this.absorbing = false,
  });

  final CompanyRecord run;
  final String destination, statusLabel;
  final int orderCount;
  final SsStatus statusKind;
  final bool expanded, absorbing;
  final VoidCallback onToggle;
  final Widget details;
  final DateTime? recordedAt;

  @override
  Widget build(BuildContext context) {
    final stops = run.records('stops').length;
    final reference = run.id.length > 8
        ? run.id.substring(run.id.length - 8)
        : run.id;
    final rider = run.string('driverName').trim();
    final riderLabel = rider.isNotEmpty
        ? 'Rider · $rider'
        : run.string('driverId').isEmpty
        ? 'Rider not assigned'
        : 'Assigned rider · name unavailable';
    final date = recordedAt;
    return AbsorbPointer(
      absorbing: absorbing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: '$destination, $statusLabel, $riderLabel',
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: SariSupplySpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            destination,
                            style: SariSupplyTypography.cardHeading,
                          ),
                        ),
                        AnimatedRotation(
                          turns: expanded ? .25 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.chevron_right,
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      riderLabel,
                      style: SariSupplyTypography.body.copyWith(
                        color: SariSupplyColors.ink600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SsStatusChip(label: statusLabel, status: statusKind),
                        Text(
                          '$orderCount ${orderCount == 1 ? 'order' : 'orders'} · '
                          '$stops ${stops == 1 ? 'stop' : 'stops'}',
                          style: SariSupplyTypography.caption.copyWith(
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Delivery #$reference',
                          style: SariSupplyTypography.caption.copyWith(
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                        if (date != null)
                          Text(
                            '${MaterialLocalizations.of(context).formatShortDate(date)} · ${TimeOfDay.fromDateTime(date).format(context)}',
                            style: SariSupplyTypography.caption.copyWith(
                              color: SariSupplyColors.ink600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) details,
          const Divider(height: 1, color: SariSupplyColors.divider),
        ],
      ),
    );
  }
}
