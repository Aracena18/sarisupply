import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  testWidgets('long task titles remain complete on a narrow phone at 200%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                  appBar: sariSupplyTaskAppBar(context,
                      title: 'Select stock location'),
                ))));
    await tester.pumpAndSettle();
    final title = tester
        .renderObject<RenderParagraph>(find.text('Select stock location'));
    expect(title.didExceedMaxLines, isFalse);
  });
  setUpAll(() async {
    final loader = FontLoader('packages/sarisupply_design_system/NunitoSans');
    for (final w in [400, 600, 700]) {
      loader.addFont(rootBundle.load('assets/fonts/NunitoSans-$w.ttf'));
    }
    await loader.load();
  });
  testWidgets('shared entry branding golden and accessible tap target',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: SariSupplyTheme.light(),
        home: Scaffold(
            body: SariSupplyEntry(
                role: 'POS',
                child: FilledButton(
                    onPressed: () {},
                    child: const Text('Sign in with Google'))))));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/brand/storefront.png',
            package: 'sarisupply_design_system'),
        tester.element(find.byType(SariSupplyEntry))));
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/brand.png'));
    semantics.dispose();
  });
}
