import 'package:admin_web/src/app/admin_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_languages_api.dart';

/// The full client translation path for the Company list (I18N-01).
void main() {
  const dutch = {
    'company.title': 'Bedrijven',
    'company.column.name': 'Bedrijf',
    'common.status.active': 'Actief',
  };

  late FakeLanguagesApi languages;
  late FakeCompaniesApi companies;

  setUp(() {
    languages = FakeLanguagesApi({'nl': dutch});
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

  testWidgets('renders in built-in English immediately, before any translation request completes', (tester) async {
    languages.userLanguage = 'nl';

    await pumpBootstrap(tester);

    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
    expect(find.text('Companies'), findsWidgets);
  });

  testWidgets('switches to the user database language when its bundle arrives', (tester) async {
    languages.userLanguage = 'nl';

    await pumpBootstrap(tester);
    await tester.pump();
    await tester.pump();
    companies.succeed([company(1, 'Almeco')]);
    await tester.pump();

    expect(find.text('Bedrijven'), findsOneWidget, reason: 'Dutch from the database');
    expect(find.text('Bedrijf'), findsOneWidget);
    expect(find.text('Actief'), findsOneWidget);
    expect(find.text('View and manage companies in Jitan.'), findsOneWidget, reason: 'missing in Dutch → English');
    expect(languages.requests, ['me/language', 'translations:nl']);
  });

  testWidgets('a user without a language stays in English with no bundle request', (tester) async {
    await pumpBootstrap(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
    expect(languages.requests, ['me/language']);
  });

  testWidgets('API unreachable: the app stays fully usable in English, no error screen', (tester) async {
    languages.userLanguage = 'nl';
    languages.failNext = const ApiClientException.network('offline');

    await pumpBootstrap(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
    expect(find.text('Can’t reach Jitan'), findsNothing);
  });

  testWidgets('a misconfigured user language still opens in English', (tester) async {
    languages.failNext = const ApiClientException.server(
      409,
      ApiError(code: ApiErrorCode.configurationError, message: 'several'),
    );

    await pumpBootstrap(tester);
    await tester.pump();
    await tester.pump();

    expect(find.text('View and manage companies in Jitan.'), findsOneWidget);
  });
}
