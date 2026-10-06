import 'package:flutter/material.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({
    super.key,
    required this.store,
    this.onAlertAction,
  });

  final InventoryStore store;
  final VoidCallback? onAlertAction;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  List<SariNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final alerts = await widget.store.detectStockAlerts();
      if (mounted) {
        setState(() {
          _notifications = alerts;
        });
      }
    } catch (_) {}
  }

  void _showNotificationSheet() {
    _refresh();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active,
                            color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text(
                          'Inventory & System Alerts (${_notifications.length})',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const Spacer(),
                        if (_notifications.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() => _notifications.clear());
                              setSheetState(() {});
                            },
                            child: const Text('Clear All'),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (_notifications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 48, color: Colors.green),
                              SizedBox(height: 12),
                              Text(
                                'All clear! No pending stock or expiry alerts.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final Color cardColor;
                            final IconData icon;

                            switch (n.severity) {
                              case NotificationSeverity.critical:
                                cardColor = Colors.red.shade50;
                                icon = Icons.error_outline;
                                break;
                              case NotificationSeverity.warning:
                                cardColor = Colors.amber.shade50;
                                icon = Icons.warning_amber_outlined;
                                break;
                              case NotificationSeverity.info:
                                cardColor = Colors.blue.shade50;
                                icon = Icons.info_outline;
                                break;
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: n.severity ==
                                          NotificationSeverity.critical
                                      ? Colors.red.shade200
                                      : n.severity ==
                                              NotificationSeverity.warning
                                          ? Colors.amber.shade300
                                          : Colors.blue.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    icon,
                                    size: 20,
                                    color: n.severity ==
                                            NotificationSeverity.critical
                                        ? Colors.red.shade700
                                        : n.severity ==
                                                NotificationSeverity.warning
                                            ? Colors.amber.shade900
                                            : Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          n.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          n.message,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      setState(
                                          () => _notifications.removeAt(index));
                                      setSheetState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _notifications.length;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          tooltip: 'Alerts',
          onPressed: _showNotificationSheet,
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
