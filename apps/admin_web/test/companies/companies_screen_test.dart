import 'package:admin_web/src/companies/companies_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
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
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.light(),
        home: Scaffold(body: CompaniesScreen(api: api, clock: () => _now)),
      ),
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

    for (final header in ['Company', 'Employees', 'Status', 'Last updated']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Locations'), findsNothing, reason: 'a company has no places of its own');
    expect(find.text('4 companies'), findsOneWidget);
    expect(find.text('Almeco'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('3 days ago'), findsOneWidget);
    expect(find.text('Active'), findsNWidgets(4), reason: 'three rows and the pill');
    expect(find.text('Inactive'), findsNWidgets(2), reason: 'one row and the pill');
    // Proceq has no event-log history: its "Last updated" is a placeholder.
    expect(find.text('—'), findsOneWidget);
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

  group('Figma 1524', () {
    final almeco = company(1, 'Almeco', employees: 15, lastUpdatedAt: DateTime(2026, 10, 7, 9, 42));
    final pca = company(2, 'PCA', employees: 8);
    final proceq = company(3, 'Proceq', active: false);

    testWidgets('the pills narrow the list to active or inactive companies', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco, pca, proceq]);
      await tester.pump();

      await tester.tap(find.text('Inactive').first);
      await tester.pump();
      expect(find.text('Proceq'), findsOneWidget);
      expect(find.text('Almeco'), findsNothing);
    });

    testWidgets('Add company: ready to type; a name already in Jitan is said at once; the new one lights up', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco, pca]);
      await tester.pump();

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company'));
      await tester.pumpAndSettle();
      expect(find.text('As people know it, e.g. Almeco.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'almecó');
      await tester.pump();
      expect(find.text('Almeco is already in Jitan.'), findsOneWidget);
      expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Add company').last).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Proceq');
      await tester.pump();
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company').last);
      await tester.pumpAndSettle();

      expect(api.writes, ['create Proceq']);
      expect(find.text('Proceq'), findsOneWidget);
      expect(find.text('Proceq added'), findsOneWidget);
      expect(find.text('Add location'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a name the server finds taken is said under the field', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco]);
      await tester.pump();
      api.writeFailure = serverError(409, 'duplicate_company_name');

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Societe');
      await tester.pump();
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company').last);
      await tester.pumpAndSettle();

      expect(find.text('Societe is already in Jitan.'), findsOneWidget);
    });

    testWidgets('a row opens the company: Save waits for a change; rename is saved', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco, pca]);
      await tester.pump();
      api.answer = (_) => company(1, 'Almeco Group', employees: 15);

      await tester.tap(find.text('Almeco'));
      await tester.pumpAndSettle();
      expect(find.text('View employees'), findsOneWidget);
      expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Save')).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Almeco Group');
      await tester.pump();
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Save'));
      await tester.pumpAndSettle();

      expect(api.writes, ['rename 1 Almeco Group']);
      expect(find.text('Almeco Group'), findsOneWidget);
    });

    testWidgets('Deactivate is saved at once, and the company greys', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco, pca]);
      await tester.pump();
      api.answer = (_) => company(2, 'PCA', active: false, employees: 8);

      await tester.tap(find.text('PCA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      expect(api.writes, ['deactivate 2']);
      expect(find.text('PCA deactivated'), findsOneWidget);
    });

    testWidgets('a later message replaces "added", whose Add location does not keep it on screen', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco, pca]);
      await tester.pump();

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Proceq');
      await tester.pump();
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company').last);
      await tester.pumpAndSettle();
      expect(find.text('Proceq added'), findsOneWidget);

      api.answer = (_) => company(2, 'PCA', active: false, employees: 8);
      await tester.tap(find.text('PCA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      expect(find.text('PCA deactivated'), findsOneWidget);
      expect(find.text('Proceq added'), findsNothing);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('PCA deactivated'), findsNothing, reason: 'messages fade');
    });

    testWidgets('while searching, a name outside the search is still said to be taken', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed([almeco, pca]);
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'PC');
      await tester.pump(const Duration(milliseconds: 400));
      api.succeed([pca]);
      await tester.pump();

      await tester.tap(find.text('PCA'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Almeco');
      await tester.pump();

      expect(find.text('Almeco is already in Jitan.'), findsOneWidget);
      expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Save')).onPressed, isNull);
    });

    testWidgets('the very first time: no card, one line and the button', (tester) async {
      final api = await _pumpScreen(tester);
      api.succeed(<CompanySummary>[]);
      await tester.pump();

      expect(find.text('No companies yet'), findsOneWidget);
      expect(find.text('Add the first one to start. Its employees, workplace and schedules follow.'), findsOneWidget);
      expect(find.widgetWithText(JitanPrimaryButton, 'Add company'), findsOneWidget, reason: 'only the one with the text');
      expect(find.text('Search companies'), findsNothing);
    });
  });
}
