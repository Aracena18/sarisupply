import 'package:flutter/material.dart';
import '../sarisupply_design_system.dart';

/// One route and one state owner across phone/page and wide/dialog layouts.
Future<T?> showSariSupplyForm<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    useSafeArea: false,
    barrierDismissible: false,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: builder,
  );
  final result = await navigator.push(route);
  // Caller-owned fields are still mounted during the reverse transition.
  await route.completed;
  return result;
}

class SariSupplyFormSurface extends StatelessWidget {
  const SariSupplyFormSurface({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 600;
    // The same content subtree retains field/focus/scroll state on resize.
    final padding = phone ? SariSupplySpacing.md : SariSupplySpacing.lg;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Text(title, style: SariSupplyTypography.screenTitle),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: child,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(padding),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: SariSupplySpacing.xs,
            runSpacing: SariSupplySpacing.xs,
            children: actions,
          ),
        ),
      ],
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: MediaQuery.viewInsetsOf(context),
      child: SafeArea(
        child: Align(
          alignment: Alignment.center,
          child: Material(
            color: SariSupplyColors.card,
            borderRadius: phone
                ? BorderRadius.zero
                : BorderRadius.circular(SariSupplyRadii.lg),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: phone ? double.infinity : 560,
              height: phone ? double.infinity : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
