import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employees_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_schedules_api.dart';
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
            body: EmployeesScreen(api: api, groupsApi: _groups, companiesApi: FakeCompaniesApi(), schedulesApi: FakeSchedulesApi()),
          ),
        ),
      ),
    ),
  );
  return (api, current);
}

void main() {
  testWidgets('without a current company: lists every company\'s employees (the switcher is only a filter)', (tester) async {
    final (api, _) = await _pump(tester);

    expect(find.text('Employees'), findsWidgets, reason: 'the title and the section heading');
    expect(find.text('Current company'), findsOneWidget);
    expect(api.calls, [(-1, '')], reason: 'all companies, no company guessed');

    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW'), employee(2, 'Kevin', 'De Vos', 'KDV')]);
    await tester.pump();
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    expect(find.text('Kevin De Vos'), findsOneWidget);
  });

  testWidgets('without a current company and no employees: the empty state names no company', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed(const []);
    await tester.pump();

    expect(find.text('Employees you add will appear here.'), findsOneWidget);
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

    expect(find.text('Location'), findsNothing, reason: 'left out: not asked when adding an employee');
    for (final header in ['Employee', 'Code', 'Type', 'Schedule', 'Onboarding', 'Actions']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Status'), findsNWidgets(2), reason: 'the filter and the column');
    expect(find.text('Policy'), findsNothing, reason: 'PRODUCT-CLARIFY-EMPLOYEE-POLICY');
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    expect(find.text('SBW'), findsOneWidget);
    expect(find.text('White collar'), findsOneWidget);
    expect(find.text('Blue collar, Night shift'), findsOneWidget, reason: 'all groups, no priority');
    expect(find.text('Active'), findsNWidgets(2));
    expect(find.text('Inactive'), findsOneWidget);
    // The nameless employee has a name placeholder and no groups; Schedule
    // per row: none of these has hours yet.
    expect(find.text('—'), findsNWidgets(2 + 3));
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
    expect(find.text('No matching employees. Change the search or the status.'), findsOneWidget);
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

  testWidgets('the Status filter shows active or inactive employees', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW'), employee(2, 'Thomas', 'Vermeulen', 'TVM', active: false)]);
    await tester.pump();

    tester.widget<JitanSelectField<EmployeeStatusFilter?>>(find.byType(JitanSelectField<EmployeeStatusFilter?>)).onChanged!(
      EmployeeStatusFilter.inactive,
    );
    await tester.pump();
    expect(find.text('Disan Ssebowa'), findsNothing);
    expect(find.text('Thomas Vermeulen'), findsOneWidget);
  });

  testWidgets('title and filters stay in place; only the list scrolls, its heading row pinned; results footer', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([for (var i = 1; i <= 60; i++) employee(i, 'First$i', 'Last', 'C$i')]);
    await tester.pump();

    final title = tester.getRect(find.text('Manage your workforce and employee onboarding'));
    final search = tester.getRect(find.text('Search name or employee code'));
    final headingBefore = tester.getRect(find.text('Onboarding'));
    expect(find.text('First40 Last'), findsNothing, reason: 'rows are built as they come into view');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pump();

    expect(tester.getRect(find.text('Manage your workforce and employee onboarding')), title, reason: 'the title stays');
    expect(tester.getRect(find.text('Search name or employee code')), search, reason: 'the filters stay');
    expect(tester.getRect(find.text('Onboarding')).top, headingBefore.top, reason: 'pinned at the top of the list');
    expect(find.text('First1 Last'), findsNothing, reason: 'rows scrolled under it');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pump();
    expect(find.text('60 employees displayed'), findsOneWidget, reason: '1399:10');
    expect(find.text('Showing 60 of 60'), findsOneWidget);
  });

  testWidgets('a short window scrolls the whole page, title included', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    tester.view.physicalSize = const Size(1440, 560);
    api.succeed([for (var i = 1; i <= 30; i++) employee(i, 'First$i', 'Last', 'C$i')]);
    await tester.pump();

    final title = tester.getRect(find.text('Manage your workforce and employee onboarding'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
    await tester.pump();

    expect(tester.getRect(find.text('Manage your workforce and employee onboarding')).top, lessThan(title.top));
  });

  testWidgets('the row "⋯": Remove employee asks first, then hides them once the server confirms', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW', companyIds: [8, 7])]);
    await tester.pump();

    await tester.tap(find.byTooltip('Employee actions'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from the active employee list'), findsOneWidget, reason: '238:3689');
    await tester.tap(find.text('Remove employee'));
    await tester.pumpAndSettle();

    expect(find.text('Remove employee?'), findsOneWidget, reason: '238:3853');
    expect(find.text('Are you sure you want to remove Disan Ssebowa?'), findsOneWidget);
    expect(find.text('This employee will be hidden from normal views. Historical records will remain available.'), findsOneWidget);
    expect(api.removes, isEmpty, reason: 'nothing before the confirmation');

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
    await tester.pump();
    expect(api.removes, [(8, 1)], reason: 'no company filter: one of the companies of the employee');
    expect(find.text('Disan Ssebowa was removed.'), findsNothing, reason: 'no success before the server confirms');

    api.removeSucceeds();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Remove employee?'), findsNothing);
    expect(find.text('Disan Ssebowa was removed.'), findsOneWidget);
    expect(api.calls, hasLength(2), reason: 'the list reloads');
  });

  testWidgets('Remove employee: a refusal stays in the dialog and says why', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();
    await tester.tap(find.byTooltip('Employee actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove employee'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
    await tester.pump();
    expect(api.removes, [(7, 1)]);
    api.removeFails(const ApiClientException.network('offline'));
    await tester.pumpAndSettle();

    expect(find.text('Remove employee?'), findsOneWidget);
    expect(api.calls, hasLength(1), reason: 'nothing changed: no reload');
  });

  testWidgets('the row "⋯": Manage employee offers the onboarding QR to someone not activated yet', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();

    await tester.tap(find.byTooltip('Employee actions'));
    await tester.pumpAndSettle();
    expect(find.text('Manage employee'), findsOneWidget);
    expect(find.text('Disan Ssebowa · Not activated'), findsOneWidget, reason: '1399:10');
    await tester.tap(find.text('Reset account access'));
    await tester.pumpAndSettle();
    expect(find.text('Manage employee'), findsOneWidget, reason: 'unavailable before activation: nothing happens');

    await tester.tap(find.text('Generate onboarding QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.detailRequests, [(7, 1)]);
    api.detailsSucceed(
      const EmployeeDetails(
        id: 1,
        companyId: 7,
        companyName: 'Almeco',
        firstName: 'Disan',
        lastName: 'Ssebowa',
        code: 'SBW',
        groups: [],
        phone: null,
        isActive: true,
        isActivated: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.qrRequests.single, (7, 1, TemporaryQrPurpose.onboarding));
  });
}
