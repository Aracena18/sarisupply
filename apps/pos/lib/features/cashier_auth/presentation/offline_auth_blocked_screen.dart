import 'package:flutter/material.dart';

class OfflineAuthBlockedScreen extends StatelessWidget {
  const OfflineAuthBlockedScreen({
    super.key,
    required this.revoked,
    required this.onRetry,
  });

  final bool revoked;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                revoked ? 'Device access revoked' : 'Reconnect to continue')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(revoked ? Icons.phonelink_erase : Icons.wifi_off,
                      size: 48),
                  const SizedBox(height: 16),
                  Text(revoked
                      ? 'Ask an Owner or Manager to activate this tablet again.'
                      : 'Connect to the internet and refresh cashier access.'),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: onRetry,
                      child: Text(revoked ? 'Set up again' : 'Try again')),
                ],
              )),
        )),
      );
}
