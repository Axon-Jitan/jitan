import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

Widget _shell({required void Function(String) onNavigate, String? roleCaption}) => MaterialApp(
      home: JitanWebShell(
        sidebar: JitanWebSidebar(
          selectedPath: '/companies',
          onNavigate: onNavigate,
          roleCaption: roleCaption,
          destinations: const [
            JitanNavDestination(label: 'Companies', path: '/companies'),
            JitanNavDestination(label: 'Employees', path: '/employees'),
          ],
        ),
        child: const Text('page'),
      ),
    );

void main() {
  void setWidth(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('wide: sidebar beside the page, selected item marked', (tester) async {
    setWidth(tester, 1440);
    await tester.pumpWidget(_shell(onNavigate: (_) {}));

    expect(find.text('page'), findsOneWidget);
    final items = tester.widgetList<JitanNavItem>(find.byType(JitanNavItem)).toList();
    expect(items.map((i) => (i.label, i.selected)), [('Companies', true), ('Employees', false)]);
  });

  testWidgets('tapping an item reports its path', (tester) async {
    setWidth(tester, 1440);
    final navigated = <String>[];
    await tester.pumpWidget(_shell(onNavigate: navigated.add));

    await tester.tap(find.text('Employees'));

    expect(navigated, ['/employees']);
  });

  testWidgets('shows the role caption only when given', (tester) async {
    setWidth(tester, 1440);
    await tester.pumpWidget(_shell(onNavigate: (_) {}));
    expect(find.text('ADMIN'), findsNothing);

    await tester.pumpWidget(_shell(onNavigate: (_) {}, roleCaption: 'ADMIN'));
    expect(find.text('ADMIN'), findsOneWidget);
  });

  testWidgets('narrow: sidebar collapses into a drawer', (tester) async {
    setWidth(tester, 600);
    await tester.pumpWidget(_shell(onNavigate: (_) {}));

    expect(find.byType(JitanNavItem), findsNothing);
    expect(find.text('page'), findsOneWidget);
  });
}
