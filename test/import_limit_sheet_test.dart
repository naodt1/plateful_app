import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plateful/features/subscription/import_credits.dart';
import 'package:plateful/features/subscription/pro_gate.dart';

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    }),
  ));
  return ctx;
}

void main() {
  testWidgets('explains the limit and why, before any purchase screen',
      (tester) async {
    final ctx = await _pumpHost(tester);
    ImportLimitSheet.show(ctx);
    await tester.pumpAndSettle();

    expect(
      find.text('You have used your ${ProLimits.freeImports} free imports'),
      findsOneWidget,
    );
    expect(find.textContaining('costs us on each import'), findsOneWidget);
    expect(find.textContaining('add recipes by hand for free'), findsOneWidget);
    expect(find.text('See Plateful Pro'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('continuing to Pro resolves true so the caller opens the paywall',
      (tester) async {
    final ctx = await _pumpHost(tester);
    final result = ImportLimitSheet.show(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Plateful Pro'));
    await tester.pumpAndSettle();

    expect(await result, isTrue);
  });

  testWidgets('declining resolves false so no paywall is shown',
      (tester) async {
    final ctx = await _pumpHost(tester);
    final result = ImportLimitSheet.show(ctx);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(await result, isFalse);
  });

  testWidgets('dismissing by tapping the barrier resolves false',
      (tester) async {
    final ctx = await _pumpHost(tester);
    final result = ImportLimitSheet.show(ctx);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // outside the sheet
    await tester.pumpAndSettle();

    expect(await result, isFalse);
  });

  testWidgets('lays out without overflow on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final ctx = await _pumpHost(tester);
    ImportLimitSheet.show(ctx);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
