import 'package:admin_web/src/app/admin_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_languages_api.dart';

/// The full client translation path for the Company list (I18N-01):
/// user language → bundles → fallback → rendered screen.
void main() {
  const english = {
    'company.title': 'Companies',
    'company.list.subtitle': 'View and manage companies in Jitan.',
    'company.column.name': 'Company',
    'common.status.active': 'Active',
    'nav.companies': 'Companies',
  };
  const dutch = {
    'company.title': 'Bedrijven',
    'company.column.name': 'Bedrijf',
    'common.status.active': 'Actief',
  };

  late FakeLanguagesApi languages;
  late FakeCompaniesApi companies;

  setUp(() {
    languages = FakeLanguagesApi({'en': english, 'nl': dutch});
    companies = FakeCompaniesApi();
  });

  Future<void> pumpBootstrap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdminBootstrap(translationService: TranslationService(languages), companiesApi: companies),
    );
  }

  testWidgets('loads the user language and renders the Company list from the database bundles', (tester) async {
    languages.userLanguage = 'nl';

    await pumpBootstrap(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'loading, no text yet');

    await tester.pump();
    await tester.pump();
    companies.succeed([company(1, 'Almeco')]);
    await tester.pump();

    expect(find.text('Bedrijven'), findsOneWidget, reason: 'Dutch title');
    expect(find.text('Bedrijf'), findsOneWidget, reason: 'Dutch column header');
    expect(find.text('Actief'), findsOneWidget);
    expect(find.text('View and manage companies in Jitan.'), findsOneWidget, reason: 'missing in Dutch → English');
    expect(find.text('company.search'), findsOneWidget, reason: 'missing everywhere → key');
    expect(languages.requests, ['me/language', 'translations:en', 'translations:nl']);
  });

  testWidgets('a user without a language gets English', (tester) async {
    await pumpBootstrap(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Companies'), findsWidgets);
    expect(languages.requests, ['me/language', 'translations:en']);
  });

  testWidgets('a failed load shows an error with retry, and retry succeeds', (tester) async {
    languages.failNext = const ApiClientException.network('offline');

    await pumpBootstrap(tester);
    await tester.pump();

    // No bundle could be loaded, so the error shows keys.
    expect(find.text('common.error.network.title'), findsOneWidget);

    await tester.tap(find.text('common.retry'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Companies'), findsWidgets);
  });

  testWidgets('a misconfigured user language still opens the app in English', (tester) async {
    languages.failNext = const ApiClientException.server(
      409,
      ApiError(code: ApiErrorCode.configurationError, message: 'several'),
    );

    await pumpBootstrap(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('Companies'), findsWidgets);
  });
}
