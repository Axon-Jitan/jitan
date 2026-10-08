import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employees_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_assignments_api.dart';
import '../support/fake_companies_api.dart';
import '../support/fake_employees_api.dart';

final _almeco = company(7, 'Almeco');
final _pca = company(8, 'PCA');

late FakeGroupsApi _groups;

Future<(FakeEmployeesApi, CurrentCompanyController)> _pump(WidgetTester tester, {CompanySummary? selected}) async {
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeEmployeesApi();
  _groups = FakeGroupsApi();
  final current = CurrentCompanyController()..select(selected);
  addTearDown(current.dispose);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: CurrentCompanyScope(
        controller: current,
        child: MaterialApp(
          theme: JitanTheme.light(),
          home: Scaffold(
            body: EmployeesScreen(api: api, groupsApi: _groups, assignmentsApi: FakeEmployeeAssignmentsApi()),
          ),
        ),
      ),
    ),
  );
  return (api, current);
}

void main() {
  testWidgets('without a current company: explains it and requests nothing', (tester) async {
    final (api, _) = await _pump(tester);

    expect(find.text('Employees'), findsOneWidget);
    expect(find.text('No company selected'), findsOneWidget);
    expect(find.text('Search name or employee code'), findsNothing);
    expect(api.calls, isEmpty, reason: 'never guesses a company');
  });

  testWidgets('loads the current company and renders every column', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    expect(find.text('Loading employees…'), findsOneWidget);
    expect(api.calls, [(7, '')]);

    api.succeed([
      employee(1, 'Disan', 'Ssebowa', 'SBW', groups: ['White collar']),
      employee(2, 'Thomas', 'Vermeulen', 'TVM', groups: ['Blue collar', 'Night shift'], active: false),
      employee(3, null, null, 'X1'),
    ]);
    await tester.pump();

    for (final header in ['Employee', 'Code', 'Type', 'Location', 'Onboarding', 'Status']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Policy'), findsNothing, reason: 'PRODUCT-CLARIFY-EMPLOYEE-POLICY');
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    expect(find.text('SBW'), findsOneWidget);
    expect(find.text('White collar'), findsOneWidget);
    expect(find.text('Blue collar, Night shift'), findsOneWidget, reason: 'all groups, no priority');
    expect(find.text('Active'), findsNWidgets(2));
    expect(find.text('Inactive'), findsOneWidget);
    // Location per row (GAP-11); the nameless employee adds a name
    // placeholder and has no groups.
    expect(find.text('—'), findsNWidgets(3 + 2));
    // Onboarding: userPassword IS NOT NULL → Activated (none of these yet).
    expect(find.text('Not activated'), findsNWidgets(3));
  });

  testWidgets('an employee who completed onboarding shows Activated', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);

    api.succeed([
      employee(1, 'Disan', 'Ssebowa', 'SBW', activated: true),
      employee(2, 'Kevin', 'De Vos', 'KDV'),
    ]);
    await tester.pump();

    expect(find.text('Activated'), findsOneWidget);
    expect(find.text('Not activated'), findsOneWidget);
  });

  testWidgets('empty company: names the company', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);

    api.succeed(<EmployeeSummary>[]);
    await tester.pump();

    expect(find.text('No employees yet'), findsOneWidget);
    expect(find.text('Employees of Almeco will appear here.'), findsOneWidget);
  });

  testWidgets('search shows a no-match state naming the search', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.calls.last, (7, 'zz'));

    api.succeed(<EmployeeSummary>[]);
    await tester.pump();

    expect(find.text('No matching employees'), findsOneWidget);
    expect(find.text('No employee name or code contains “zz”.'), findsOneWidget);
  });

  testWidgets('switching company loads the new company and never shows the old rows', (tester) async {
    final (api, current) = await _pump(tester, selected: _almeco);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();
    expect(find.text('Disan Ssebowa'), findsOneWidget);

    current.select(_pca);
    await tester.pump();

    expect(find.text('Disan Ssebowa'), findsNothing);
    expect(find.text('Loading employees…'), findsOneWidget);
    expect(api.calls.last, (8, ''));

    api.succeed([employee(9, 'Paula', 'Claes', 'PCL')]);
    await tester.pump();
    expect(find.text('Paula Claes'), findsOneWidget);
  });

  testWidgets('a deleted company shows "Not found" with retry', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);

    api.fail(const ApiClientException.server(404, ApiError(code: ApiErrorCode.notFound, message: 'x')));
    await tester.pump();

    expect(find.text('Not found'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(api.calls, hasLength(2));
  });
}
