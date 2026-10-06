import 'package:flutter/material.dart';

/// One route and one state owner across phone/page and wide/dialog layouts.
Future<T?> showSariSupplyForm<T>(
        {required BuildContext context, required WidgetBuilder builder}) =>
    showDialog<T>(
        context: context,
        useSafeArea: false,
        barrierDismissible: false,
        builder: builder);

class SariSupplyFormSurface extends StatelessWidget {
  const SariSupplyFormSurface(
      {super.key,
      required this.title,
      required this.child,
      required this.actions});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    // The same content subtree retains field/focus/scroll state on resize.
    final padding = phone ? 16.0 : 24.0;
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
              padding: EdgeInsets.all(padding),
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          Flexible(
              child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: child)),
          Padding(
              padding: EdgeInsets.all(padding),
              child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions)),
        ]);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: MediaQuery.viewInsetsOf(context),
      child: SafeArea(
          child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: phone ? BorderRadius.zero : BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
              width: phone ? double.infinity : 560,
              height: phone ? double.infinity : null,
              child: content),
        ),
      )),
    );
  }
}
