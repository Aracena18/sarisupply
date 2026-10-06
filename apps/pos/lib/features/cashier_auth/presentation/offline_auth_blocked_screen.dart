import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

class OfflineAuthBlockedScreen extends StatelessWidget {
  const OfflineAuthBlockedScreen(
      {super.key,
      required this.revoked,
      required this.onRetry,
      this.recoveryMessage});
  final bool revoked;
  final VoidCallback onRetry;
  final String? recoveryMessage;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SariSupplyEntry(
          role: 'POS',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(
                revoked
                    ? 'Device access revoked'
                    : recoveryMessage == null
                        ? 'Reconnect to continue'
                        : 'Refresh access to continue',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SariSupplyStatus(
                icon: revoked
                    ? Icons.phonelink_erase
                    : recoveryMessage == null
                        ? Icons.wifi_off
                        : Icons.info_outline,
                message: revoked
                    ? 'Ask an Owner or Manager to activate this device again.'
                    : recoveryMessage ??
                        'Connect to the internet and refresh cashier access.'),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: onRetry,
                child: Text(revoked ? 'Set up again' : 'Refresh access')),
          ])));
}
