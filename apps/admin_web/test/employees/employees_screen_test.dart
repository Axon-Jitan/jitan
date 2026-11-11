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
import '../support/fake_schedules_api.dart';

final _almeco = company(7, 'Almeco');
final _pca = company(8, 'PCA');

late FakeGroupsApi _groups;
late FakeCompaniesApi _companies;

Future<(FakeEmployeesApi, CurrentCompanyController)> _pump(WidgetTester tester, {CompanySummary? selected}) async {
  tester.view.physicalSize = const Size(1440, 1024);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = FakeEmployeesApi();
  _groups = FakeGroupsApi();
  _companies = FakeCompaniesApi();
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
            body: EmployeesScreen(
              api: api,
              groupsApi: _groups,
              companiesApi: _companies,
              schedulesApi: FakeSchedulesApi(),
              assignmentsApi: FakeEmployeeAssignmentsApi(),
            ),
          ),
        ),
      ),
    ),
  );
  return (api, current);
}

void main() {
  testWidgets('without a current company: lists every company’s employees (the company is only a filter)', (tester) async {
    final (api, _) = await _pump(tester);

    expect(find.text('All companies'), findsOneWidget);
    expect(api.calls, [(-1, '')], reason: 'all companies, no company guessed');

    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW'), employee(2, 'Kevin', 'De Vos', 'KDV')]);
    await tester.pump();
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    expect(find.text('Kevin De Vos'), findsOneWidget);
    expect(find.text('2 employees'), findsOneWidget, reason: 'the count under the title');
  });

  testWidgets('without a current company and no employees: the empty state names no company', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed(const []);
    await tester.pump();

    expect(find.text('Employees you add will appear here.'), findsOneWidget);
  });

  testWidgets('Figma 1531:2: five columns, one status (Active, Not set up, Inactive)', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    expect(find.text('Loading employees…'), findsOneWidget);
    expect(api.calls, [(7, '')]);

    api.succeed([
      employee(1, 'Disan', 'Ssebowa', 'SBW', groups: ['White collar'], activated: true),
      employee(2, 'Thomas', 'Vermeulen', 'TVM', groups: ['Blue collar', 'Night shift'], active: false),
      employee(3, null, null, 'X1'),
    ]);
    await tester.pump();

    for (final header in ['Employee', 'Code', 'Type', 'Schedule', 'Status']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    for (final gone in ['Onboarding', 'Actions', 'Location', 'Policy', 'Current company']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.text('Employees'), findsOneWidget, reason: 'the title only, no section heading');
    expect(find.byTooltip('Employee actions'), findsNothing, reason: 'no ⋯: a row opens the employee');
    expect(find.text('Blue collar, Night shift'), findsOneWidget, reason: 'all groups, no priority');
    expect(find.text('Active'), findsNWidgets(2), reason: 'the button and Disan');
    expect(find.text('Inactive'), findsNWidgets(2), reason: 'the button and Thomas');
    expect(find.text('Not set up'), findsNWidgets(2), reason: 'the button and X1');
    expect(find.text('Activated'), findsNothing);
  });

  testWidgets('empty company: names the company', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);

    api.succeed(<EmployeeSummary>[]);
    await tester.pump();

    expect(find.text('No employees yet'), findsOneWidget);
    expect(find.text('Employees of Almeco will appear here.'), findsOneWidget);
  });

  testWidgets('search shows a no-match state', (tester) async {
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

  testWidgets('the status buttons: Active, Not set up and Inactive each show their own', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([
      employee(1, 'Disan', 'Ssebowa', 'SBW'),
      employee(2, 'Kevin', 'De Vos', 'KDV', activated: true),
      employee(3, 'Thomas', 'Vermeulen', 'TVM', active: false),
    ]);
    await tester.pump();

    Future<List<String>> shownAfter(String button) async {
      await tester.tap(find.text(button).first);
      await tester.pump();
      return [
        for (final name in ['Disan Ssebowa', 'Kevin De Vos', 'Thomas Vermeulen'])
          if (find.text(name).evaluate().isNotEmpty) name,
      ];
    }

    expect(await shownAfter('Active'), ['Kevin De Vos'], reason: 'set up and active');
    expect(await shownAfter('Not set up'), ['Disan Ssebowa'], reason: 'active, onboarding not done');
    expect(await shownAfter('Inactive'), ['Thomas Vermeulen']);
    expect(await shownAfter('All'), ['Disan Ssebowa', 'Kevin De Vos', 'Thomas Vermeulen']);
  });

  testWidgets('title and filters stay in place; only the list scrolls, its heading row pinned', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([for (var i = 1; i <= 60; i++) employee(i, 'First$i', 'Last', 'C$i')]);
    await tester.pump();

    final title = tester.getRect(find.text('60 employees'));
    final search = tester.getRect(find.text('Search name or code'));
    final headingBefore = tester.getRect(find.text('Schedule'));
    expect(find.text('First40 Last'), findsNothing, reason: 'rows are built as they come into view');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pump();

    expect(tester.getRect(find.text('60 employees')), title, reason: 'the title stays');
    expect(tester.getRect(find.text('Search name or code')), search, reason: 'the filters stay');
    expect(tester.getRect(find.text('Schedule')).top, headingBefore.top, reason: 'pinned at the top of the list');
    expect(find.text('First1 Last'), findsNothing, reason: 'rows scrolled under it');
  });

  testWidgets('a short window scrolls the whole page, title included', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    tester.view.physicalSize = const Size(1440, 560);
    api.succeed([for (var i = 1; i <= 30; i++) employee(i, 'First$i', 'Last', 'C$i')]);
    await tester.pump();

    final title = tester.getRect(find.text('30 employees'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
    await tester.pump();

    expect(tester.getRect(find.text('30 employees')).top, lessThan(title.top));
  });

  testWidgets('the company can go back to All companies', (tester) async {
    final (api, current) = await _pump(tester, selected: _almeco);
    for (var i = 0; i < _companies.calls.length; i++) {
      _companies.succeed([_almeco, _pca], index: i);
    }
    api.succeed(const []);
    await tester.pump();
    expect(api.calls, [(7, '')]);

    await tester.tap(find.text('Almeco'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All companies').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(current.company, isNull);
    expect(api.calls.last, (-1, ''), reason: 'every company again');
  });

  testWidgets('the search × clears the search and reloads the full list', (tester) async {
    final (api, _) = await _pump(tester, selected: _almeco);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'dis');
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls.last, (7, 'dis'));
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.calls.last, (7, ''));
    expect(find.byTooltip('Clear search'), findsNothing, reason: 'only while there is text');
  });
}
