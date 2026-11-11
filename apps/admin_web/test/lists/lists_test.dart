import 'package:admin_web/src/lists/lists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_lists.dart';

void main() {
  late FakeListsApi api;

  setUp(() => api = FakeListsApi());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.web(),
          home: Scaffold(body: ListsScreen(api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('needs setup: what is missing, list by list (Figma 1510:2)', (tester) async {
    await pump(tester);

    expect(find.text('2 lists are missing something'), findsOneWidget);
    expect(find.text('Terminal kinds'), findsOneWidget);
    expect(find.text('3 missing'), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);
    expect(find.text('15 of 15'), findsOneWidget);
    expect(find.text('Ready'), findsNWidgets(6));
  });

  testWidgets('Add what’s missing adds everything, and the card goes (Figma 1510:387)', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add what’s missing'));
    await tester.pumpAndSettle();

    expect(api.calls, ['add all']);
    expect(find.text('2 lists are missing something'), findsNothing);
    expect(find.text('Ready'), findsNWidgets(8));
  });

  testWidgets('one list: its missing entries and one button for exactly those (Figma 1510:221)', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Terminal kinds'));
    await tester.pumpAndSettle();

    expect(find.text('Office terminal'), findsOneWidget);
    expect(find.text('Missing'), findsNWidgets(3));
    await tester.tap(find.text('Add all 3'));
    await tester.pumpAndSettle();

    expect(api.calls, ['add terminal_kinds']);
    expect(find.text('Added'), findsNWidgets(3));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('1 list is missing something'), findsOneWidget);
  });
}
