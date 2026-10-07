import 'package:admin_web/src/app/admin_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';

void main() {
  void useDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('opens on Companies with the sidebar showing it as selected', (tester) async {
    useDesktopSize(tester);
    final api = FakeCompaniesApi();

    await tester.pumpWidget(AdminApp(companiesApi: api));
    await tester.pump();

    expect(find.text('jitan.'), findsOneWidget);
    final item = tester.widget<JitanNavItem>(find.byType(JitanNavItem));
    expect(item.label, 'Companies');
    expect(item.selected, isTrue);
    expect(api.calls, [''], reason: 'the page loads companies on open');
  });

  testWidgets('the sidebar lists only built pages (no dead navigation)', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(AdminApp(companiesApi: FakeCompaniesApi()));
    await tester.pump();

    expect(find.byType(JitanNavItem), findsOneWidget);
    for (final unbuilt in ['Dashboard', 'Employees', 'Terminals', 'Time records', 'Exceptions', 'Reports']) {
      expect(find.text(unbuilt), findsNothing, reason: unbuilt);
    }
  });

  testWidgets('an unknown URL lands on Companies', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(AdminApp(companiesApi: FakeCompaniesApi(), initialLocation: '/nope'));
    await tester.pump();

    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
  });

  testWidgets('a narrow window moves the sidebar into a drawer', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AdminApp(companiesApi: FakeCompaniesApi()));
    await tester.pump();

    expect(find.byType(JitanNavItem), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    // Not pumpAndSettle: the page's loading spinner animates indefinitely.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JitanNavItem), findsOneWidget);
  });
}
