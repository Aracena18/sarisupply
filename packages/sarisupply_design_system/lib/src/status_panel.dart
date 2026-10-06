import 'package:flutter/material.dart';

/// Text and icon distinguish status without relying on color alone.
class SariSupplyStatus extends StatelessWidget {
  const SariSupplyStatus(
      {super.key,
      required this.message,
      this.icon = Icons.info_outline,
      this.error = false,
      this.actions = const []});
  final String message;
  final IconData icon;
  final bool error;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: error
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon,
                color: error ? Theme.of(context).colorScheme.error : null),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ]),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ]),
      ));
}
