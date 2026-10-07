import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/company_context/dev_company_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';

Future<(FakeCompaniesApi, CurrentCompanyController)> _pump(WidgetTester tester) async {
  final api = FakeCompaniesApi();
  final current = CurrentCompanyController();
  addTearDown(current.dispose);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: CurrentCompanyScope(
        controller: current,
        child: MaterialApp(home: Scaffold(body: DevCompanySelector(companiesApi: api))),
      ),
    ),
  );
  return (api, current);
}

void main() {
  testWidgets('lists companies and sets the current company; nothing is preselected', (tester) async {
    final (api, current) = await _pump(tester);
    api.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
    await tester.pump();

    expect(find.text('DEV · Current company'), findsOneWidget);
    expect(find.text('Choose a company'), findsOneWidget);
    expect(current.company, isNull);

    await tester.tap(find.text('Choose a company'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PCA').last);
    await tester.pumpAndSettle();

    expect(current.company?.id, 8);
  });

  testWidgets('a load failure offers retry', (tester) async {
    final (api, _) = await _pump(tester);
    api.fail(const ApiClientException.network('offline'));
    await tester.pump();

    expect(find.text('Companies could not be loaded.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(api.calls, hasLength(2));
  });

  test('CurrentCompanyController notifies only on a real change', () {
    final controller = CurrentCompanyController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller
      ..select(company(7, 'Almeco'))
      ..select(company(7, 'Almeco'))
      ..select(null);

    expect(notifications, 2);
    controller.dispose();
  });
}
