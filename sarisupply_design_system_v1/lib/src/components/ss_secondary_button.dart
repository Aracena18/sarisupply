import 'package:flutter/material.dart';

class SsSecondaryButton extends StatelessWidget {
  const SsSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(label),
      ],
    );

    final button = OutlinedButton(onPressed: onPressed, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
