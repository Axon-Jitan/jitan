import 'package:admin_web/src/app/admin_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/test_translations.dart';

void main() {
  void useDesktopSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(FakeCompaniesApi api, {String? initialLocation}) =>
      withTestTranslations(AdminApp(companiesApi: api, initialLocation: initialLocation));

  testWidgets('opens on Companies with the sidebar showing it as selected', (tester) async {
    useDesktopSize(tester);
    final api = FakeCompaniesApi();

    await tester.pumpWidget(app(api));
    await tester.pump();

    expect(find.text('jitan.'), findsOneWidget);
    final item = tester.widget<JitanNavItem>(find.byType(JitanNavItem));
    expect(item.label, 'nav.companies');
    expect(item.selected, isTrue);
    expect(api.calls, [''], reason: 'the page loads companies on open');
  });

  testWidgets('the sidebar lists only built pages (no dead navigation)', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(app(FakeCompaniesApi()));
    await tester.pump();

    expect(find.byType(JitanNavItem), findsOneWidget);
  });

  testWidgets('an unknown URL lands on Companies', (tester) async {
    useDesktopSize(tester);

    await tester.pumpWidget(app(FakeCompaniesApi(), initialLocation: '/nope'));
    await tester.pump();

    expect(find.text('company.list.subtitle'), findsOneWidget);
  });

  testWidgets('a narrow window moves the sidebar into a drawer', (tester) async {
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(FakeCompaniesApi()));
    await tester.pump();

    expect(find.byType(JitanNavItem), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    // Not pumpAndSettle: the page's loading spinner animates indefinitely.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(JitanNavItem), findsOneWidget);
  });
}
