import 'package:admin_web/src/companies/companies_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';

final _now = DateTime(2026, 10, 7, 14);

Future<FakeCompaniesApi> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeCompaniesApi();
  await tester.pumpWidget(
    MaterialApp(
      theme: JitanTheme.light(),
      home: Scaffold(body: CompaniesScreen(api: api, clock: () => _now)),
    ),
  );
  return api;
}

void main() {
  testWidgets('shows the header and a loading state first', (tester) async {
    await _pumpScreen(tester);

    expect(find.text('Companies'), findsOneWidget);
    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
    expect(find.text('Search companies'), findsOneWidget);
    expect(find.text('Loading companies…'), findsOneWidget);
  });

  testWidgets('renders every column from the API data', (tester) async {
    final api = await _pumpScreen(tester);

    api.succeed([
      company(1, 'Almeco', employees: 48, lastUpdatedAt: DateTime(2026, 10, 7, 9)),
      company(2, 'PCA', employees: 36, lastUpdatedAt: DateTime(2026, 10, 6, 23, 50)),
      company(3, 'Akwa Plus', employees: 21, lastUpdatedAt: DateTime(2026, 10, 4)),
      company(4, 'Proceq', active: false, employees: 19),
    ]);
    await tester.pump();

    for (final header in ['Company', 'Employees', 'Locations', 'Status', 'Last updated']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Almeco'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.text('Active'), findsNWidgets(3));
    expect(find.text('Inactive'), findsOneWidget);
    // Locations: no data source yet (ERD GAP-03), shown as a placeholder,
    // never as a number. Proceq has no event-log history, so its
    // "Last updated" is the same placeholder.
    expect(find.text('—'), findsNWidgets(5));
  });

  testWidgets('shows the empty state when there are no companies', (tester) async {
    final api = await _pumpScreen(tester);

    api.succeed(<CompanySummary>[]);
    await tester.pump();

    expect(find.text('No companies yet'), findsOneWidget);
    expect(find.text('Company'), findsNothing, reason: 'no empty table');
  });

  testWidgets('searching shows a no-match state naming the search', (tester) async {
    final api = await _pumpScreen(tester);
    api.succeed([company(1, 'Almeco')]);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Zeta');
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.calls.last, 'Zeta');

    api.succeed(<CompanySummary>[]);
    await tester.pump();

    expect(find.text('No matching companies'), findsOneWidget);
    expect(find.text('No company name contains “Zeta”.'), findsOneWidget);
  });

  testWidgets('a failure shows an error with retry, and retry reloads', (tester) async {
    final api = await _pumpScreen(tester);

    api.fail(serverError(503, ApiErrorCode.databaseUnavailable));
    await tester.pump();

    expect(find.text('Jitan is temporarily unavailable'), findsOneWidget);
    expect(find.text('server detail'), findsNothing, reason: 'server diagnostics are not shown');

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(api.calls, hasLength(2));

    api.succeed([company(1, 'Almeco')]);
    await tester.pump();
    expect(find.text('Almeco'), findsOneWidget);
  });

  testWidgets('maps each failure kind to its own message', (tester) async {
    final cases = <ApiClientException, String>{
      const ApiClientException.network('offline'): 'Can’t reach Jitan',
      serverError(401, ApiErrorCode.unauthenticated): 'You’re not signed in',
      serverError(403, ApiErrorCode.forbidden): 'No access',
      serverError(500, ApiErrorCode.internalError): 'Something went wrong',
      const ApiClientException.invalidResponse(502, 'html'): 'Something went wrong',
    };
    for (final MapEntry(key: failure, value: title) in cases.entries) {
      final api = await _pumpScreen(tester);
      api.fail(failure);
      await tester.pump();
      expect(find.text(title), findsOneWidget, reason: '$failure');
      await tester.pumpWidget(const SizedBox());
    }
  });
}
