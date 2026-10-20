import 'package:admin_web/src/app/admin_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/test_services.dart';

void main() {
  void useDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(TestServices fakes, {String? initialLocation}) => TranslationScope(
        translations: Translations.english(),
        child: AdminApp(services: fakes.services, initialLocation: initialLocation),
      );

  testWidgets('opens on Companies with the sidebar showing it as selected', (tester) async {
    useDesktopSize(tester);
    final fakes = TestServices();

    await tester.pumpWidget(app(fakes));
    await tester.pump();

    expect(find.text('jitan.'), findsOneWidget);
    final items = tester.widgetList<JitanNavItem>(find.byType(JitanNavItem)).toList();
    expect(items.map((i) => (i.label, i.selected)), [('Companies', true), ('Employees', false), ('Schedules', false), ('Groups', false)]);
    expect(fakes.companies.calls, [''], reason: 'the page loads companies on open');
  });

  testWidgets('the sidebar lists only built pages (no dead navigation)', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(app(TestServices()));
    await tester.pump();

    expect(find.byType(JitanNavItem), findsNWidgets(4));
    for (final unbuilt in ['Dashboard', 'Terminals', 'Time records', 'Exceptions', 'Reports']) {
      expect(find.text(unbuilt), findsNothing, reason: unbuilt);
    }
  });

  testWidgets('navigates to Schedules from the sidebar', (tester) async {
    useDesktopSize(tester);

    final services = TestServices();
    await tester.pumpWidget(app(services));
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanNavItem, 'Schedules'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Manage time registration, breaks and rounding.'), findsOneWidget);
    expect(services.schedules.listCalls, 1);
  });

  testWidgets('navigates to Employees from the sidebar', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(app(TestServices()));
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanNavItem, 'Employees'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Manage employees for the selected company and track onboarding.'), findsOneWidget);
  });

  testWidgets('without dev tools there is no development company selector', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(app(TestServices(), initialLocation: '/employees'));
    await tester.pump();

    expect(find.text('DEV · Current company'), findsNothing);
    expect(find.text('No company selected'), findsOneWidget);
  });

  testWidgets('an unknown URL lands on Companies', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(app(TestServices(), initialLocation: '/nope'));
    await tester.pump();

    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
  });

  testWidgets('a narrow window moves the sidebar into a drawer', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(TestServices()));
    await tester.pump();

    expect(find.byType(JitanNavItem), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    // Not pumpAndSettle: the page's loading spinner animates indefinitely.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JitanNavItem), findsNWidgets(4));
  });
}
