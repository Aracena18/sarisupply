import 'package:flutter/material.dart';

/// Shared readable width, safe-area and keyboard-aware scrolling for task screens.
class SariSupplyPageContent extends StatelessWidget {
  const SariSupplyPageContent(
      {super.key, required this.child, this.maxWidth = 900});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SafeArea(
          child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
            child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
              padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
              child: child),
        )),
      ));
}
