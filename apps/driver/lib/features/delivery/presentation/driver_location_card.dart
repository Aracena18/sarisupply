import 'package:flutter/material.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'driver_location_controller.dart';

class DriverLocationCard extends StatelessWidget {
  const DriverLocationCard({super.key, required this.controller});
  final DriverLocationController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final last = controller.lastSuccessful;
        final status = controller.busy
            ? 'Getting and sharing location…'
            : !controller.enabled
                ? 'Location sharing stopped'
                : !controller.foreground
                    ? 'Location sharing paused'
                    : controller.error != null
                        ? 'Location update failed'
                        : last == null
                            ? 'Waiting for location'
                            : last.isFresh(DateTime.now())
                                ? 'Location shared'
                                : 'Last known location';
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Driver location',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(status),
                      const Text(
                          'Shares every 30 seconds while Driver is open. Pauses in Maps or when the phone locks.'),
                      if (last != null) ...[
                        const SizedBox(height: 8),
                        Text('Last shared: ${last.receivedAt.toLocal()}'),
                        Text('Accuracy: ±${last.fix.accuracyMeters.round()} m'),
                      ],
                      if (controller.error != null)
                        SariSupplyStatus(
                            message: controller.error!, error: true),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton(
                            onPressed: controller.enabled
                                ? controller.stop
                                : controller.busy
                                    ? null
                                    : controller.start,
                            child: Text(controller.enabled
                                ? 'Stop sharing'
                                : 'Start sharing location')),
                        if (controller.enabled)
                          OutlinedButton(
                              onPressed:
                                  controller.busy ? null : controller.updateNow,
                              child: const Text('Update now')),
                        if (controller.error != null) ...[
                          TextButton(
                              onPressed: GeolocatorAndroid().openAppSettings,
                              child: const Text('App settings')),
                          TextButton(
                              onPressed:
                                  GeolocatorAndroid().openLocationSettings,
                              child: const Text('Location settings')),
                        ],
                      ]),
                    ])));
      });
}
