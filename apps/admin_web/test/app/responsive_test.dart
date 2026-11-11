import 'dart:async';

import 'dart:convert';

import 'package:admin_web/src/companies/companies_screen.dart';
import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employees_screen.dart';
import 'package:admin_web/src/employees/import/employee_import_screen.dart';
import 'package:admin_web/src/employees/import/platform/import_file_picker.dart';
import 'package:admin_web/src/groups/group_page.dart';
import 'package:admin_web/src/groups/groups_screen.dart';
import 'package:admin_web/src/locations/locations_screen.dart';
import 'package:admin_web/src/dashboard/dashboard_screen.dart';
import 'package:admin_web/src/period/period_button.dart';
import 'package:admin_web/src/projects/projects_screen.dart';
import 'package:admin_web/src/lists/lists_screen.dart';
import 'package:admin_web/src/terminals/terminals_screen.dart';
import 'package:admin_web/src/reports/reports_screen.dart';
import 'package:admin_web/src/schedules/schedule_form_fields.dart';
import 'package:admin_web/src/schedules/schedule_dialog.dart';
import 'package:admin_web/src/schedules/schedules_screen.dart';
import 'package:admin_web/src/time_records/time_records_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';
import 'package:jitan_api_client/jitan_api_client.dart';

import '../support/fake_assignments_api.dart';
import '../support/fake_companies_api.dart';
import '../support/fake_employees_api.dart';
import '../support/fake_group_apis.dart';
import '../support/fake_locations.dart';
import '../support/fake_dashboard.dart';
import '../support/fake_projects.dart';
import '../support/fake_lists.dart';
import '../support/fake_terminals.dart';
import '../support/fake_reports.dart';
import '../support/fake_schedules_api.dart';
import '../support/fake_time_records_api.dart';

/// Every page and dialog works from a phone to a wide screen: nothing
/// overflows, nothing is wider than the window.
const _widths = [390.0, 820.0, 1440.0, 2400.0];

Future<void> _pump(WidgetTester tester, double width, Widget page) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final current = CurrentCompanyController()..select(company(7, 'Almeco'));
  addTearDown(current.dispose);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: CurrentCompanyScope(
        controller: current,
        child: MaterialApp(
          theme: JitanTheme.web(),
          home: JitanWebShell(
            sidebar: JitanWebSidebar(
              selectedPath: '/',
              onNavigate: (_) {},
              destinations: const [JitanNavDestination(label: 'Schedules', path: '/')],
            ),
            child: page,
          ),
        ),
      ),
    ),
  );
}

/// Lets a modal open or close (no pumpAndSettle: some states animate).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Employees with one employee, whose row opens their pop-up (Figma
/// `1531:259`).
Widget _detailsOpener(FakeEmployeesApi employees) => EmployeesScreen(
  api: employees,
  groupsApi: FakeGroupsApi(),
  companiesApi: FakeCompaniesApi(),
  schedulesApi: FakeSchedulesApi(),
  assignmentsApi: FakeEmployeeAssignmentsApi(),
);

/// Lists Disan and opens the row.
Future<void> _openEmployee(WidgetTester tester, FakeEmployeesApi employees) async {
  employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW', companyIds: [7])]);
  await _settle(tester);
  await tester.tap(find.text('Disan Ssebowa'));
}

const _activated = EmployeeDetails(
  id: 1,
  companyId: 7,
  companyName: 'Almeco',
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: ['White collar', 'Blue collar'],
  phone: '+32 470 12 34 56',
  isActive: true,
  isActivated: true,
);

void _fitsTheWindow(WidgetTester tester, double width, String what) {
  final error = tester.takeException();
  if (error is FlutterError) debugPrint(error.toStringDeep());
  expect(error, isNull, reason: '$what at $width px: no overflow');
  for (final finder in [find.byType(JitanPrimaryButton), find.byType(JitanSelectField<int?>), find.byType(JitanSearchField)]) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.right, lessThanOrEqualTo(width + 0.5), reason: '$what at $width px: ${element.widget.runtimeType} inside the window');
    }
  }
}

void main() {
  final blue = groupSchedule(
    1,
    'Blue collar',
    work: workDays([1, 2, 3, 4, 5], '07:30', '17:30'),
    breakDays: breaks([1, 2, 3, 4, 5], '12:00', 15),
  );
  final white = groupSchedule(2, 'White collar', status: GroupScheduleStatus.noSchedule);

  for (final width in _widths) {
    testWidgets('Projects and Add project at $width px', (tester) async {
      final api = FakeProjectsApi()..projects = [projectDetails(), projectDetails(id: 4, name: 'A project with a really rather long name indeed')];
      await _pump(tester, width, ProjectsScreen(api: api, locationsApi: FakeLocationsApi(), maps: null));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Projects');

      await tester.tap(find.text('Add project'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add project');
    });

    testWidgets('Lists and one list at $width px', (tester) async {
      await _pump(tester, width, ListsScreen(api: FakeListsApi()));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Lists');

      await tester.tap(find.text('Terminal kinds'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Terminal kinds');
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
    });

    testWidgets('Terminals, Add terminal and Manage at $width px', (tester) async {
      final api = FakeTerminalsApi()
        ..terminals = [officeTerminal(), officeTerminal(id: 2, name: 'A terminal with a really rather long name indeed')];
      await _pump(
        tester,
        width,
        TerminalsScreen(api: api, clock: () => DateTime(2026, 11, 1, 9)),
      );
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Terminals');

      await tester.tap(find.text('Add terminal'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add terminal');
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tester.tap(find.text('Almeco Reception'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Manage');
      await tester.tap(find.text('Deactivate'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Deactivate terminal');
    });

    testWidgets('an inactive terminal, no matches and no terminals at $width px', (tester) async {
      final api = FakeTerminalsApi()..terminals = [officeTerminal(status: TerminalStatus.inactive)];
      await _pump(tester, width, TerminalsScreen(api: api, clock: () => DateTime(2026, 11, 1, 9)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Almeco Reception'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'inactive terminal');
      await tester.tapAt(const Offset(4, 4));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, 'nothing here');
      await _settle(tester);
      _fitsTheWindow(tester, width, 'no matching terminals');

      api.terminals = [];
      await _pump(tester, width, TerminalsScreen(key: const ValueKey('empty'), api: api, clock: () => DateTime(2026, 11, 1, 9)));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'no terminals');
    });

    testWidgets('Dashboard and its period picker at $width px', (tester) async {
      final api = FakeDashboardApi()..answer = dashboardWith(bars: 31);
      await _pump(tester, width, DashboardScreen(api: api, store: MemorySessionStore(), today: () => DateTime(2026, 10, 31)));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Dashboard');

      await tester.tap(find.text('Last 7 days'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'The period picker');
    });

    testWidgets('Reports and an employee\'s month at $width px', (tester) async {
      final api = FakeReportsApi()
        ..employees = [
          reportEmployee(
            1,
            'Fabian',
            'Peeters',
            'FPT',
            toReview: 3,
            days: [HoursReportDay(date: DateTime.utc(2026, 10, 21), status: TimeRecordStatus.missingFinish, start: '08:00')],
          ),
        ];
      await _pump(tester, width, ReportsScreen(api: api, companiesApi: FakeCompaniesApi(), today: () => DateTime(2026, 10, 23)));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Reports');

      await tester.tap(find.byType(PeriodButton));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'The Reports period picker');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Difference'), findsNWidgets(width < JitanDimensions.phoneBreakpoint ? 1 : 2), reason: 'a phone keeps the table simple');

      await tester.scrollUntilVisible(find.textContaining('Fabian Peeters'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.textContaining('Fabian Peeters'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'An employee\'s month');
    });

    testWidgets('Reports, Projects and a project’s month at $width px', (tester) async {
      final api = FakeReportsApi()
        ..projectRows = [
          reportProject(
            3,
            'P-1042',
            'Office refurbishment with a long name',
            travel: 310,
            trips: 3,
            metres: 412000,
            unknownTrips: 1,
            employees: const [
              ProjectReportEmployee(employeeId: 1, firstName: 'Fabian', lastName: 'Peeters', code: 'FPT', days: 9, workedMinutes: 4350, travelMinutes: 270, trips: 2),
            ],
          ),
        ];
      await _pump(tester, width, ReportsScreen(api: api, companiesApi: FakeCompaniesApi(), today: () => DateTime(2026, 10, 23)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Projects'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Reports, Projects');

      await tester.scrollUntilVisible(find.textContaining('P-1042'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.textContaining('P-1042'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'A project’s month');
    });

    testWidgets('empty Reports at $width px', (tester) async {
      await _pump(tester, width, ReportsScreen(api: FakeReportsApi(), companiesApi: FakeCompaniesApi(), today: () => DateTime(2026, 10, 23)));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'empty Reports');
    });

    testWidgets('Locations page and its dialogs at $width px', (tester) async {
      final api = FakeLocationsApi()..locations.addAll([location(1, 'Almeco office'), location(2, 'Old depot', active: false)]);
      await _pump(tester, width, LocationsScreen(api: api, maps: fakeLocationMaps()));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Locations');

      await tester.tap(find.text('Add location').first);
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add location');
      await tester.ensureVisible(find.text('Cancel'));
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tester.tap(find.text('Almeco office'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Edit location');
      await tester.ensureVisible(find.text('Deactivate'));
      await tester.tap(find.text('Deactivate'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Deactivate location');
    });

    testWidgets('an inactive location and no inactive ones at $width px', (tester) async {
      final api = FakeLocationsApi()..locations.addAll([location(1, 'Almeco office'), location(2, 'Old depot', active: false)]);
      await _pump(tester, width, LocationsScreen(api: api, maps: fakeLocationMaps()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Old depot'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'inactive location');
      await tester.ensureVisible(find.text('Cancel'));
      await _settle(tester);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, 'nothing here');
      await _settle(tester);
      _fitsTheWindow(tester, width, 'no matching locations');
    });

    testWidgets('empty Locations page at $width px', (tester) async {
      await _pump(tester, width, LocationsScreen(api: FakeLocationsApi(), maps: fakeLocationMaps()));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'empty Locations');
    });

    testWidgets('Schedules page at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([blue, white]);
      await tester.pump();

      _fitsTheWindow(tester, width, 'Schedules');
      expect(find.text('Blue collar'), findsWidgets);
    });

    testWidgets('Companies page at $width px', (tester) async {
      final api = FakeCompaniesApi();
      await _pump(tester, width, CompaniesScreen(api: api));
      api.succeed([company(1, 'Almeco', employees: 4), company(2, 'PCA', employees: 2)]);
      await tester.pump();

      _fitsTheWindow(tester, width, 'Companies');

      await tester.tap(find.text('Almeco'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'A company');
      await tester.tap(find.text('Close'));
      await _settle(tester);

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add company'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add company');
    });

    testWidgets('Companies the very first time at $width px', (tester) async {
      final api = FakeCompaniesApi();
      await _pump(tester, width, CompaniesScreen(api: api));
      api.succeed(const []);
      await tester.pump();
      _fitsTheWindow(tester, width, 'No companies yet');
    });

    testWidgets('the schedule wizard, every step, at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([blue, white]);
      await tester.pump();
      unawaited(showScheduleDialog(tester.element(find.byType(SchedulesScreen)), api: api, groups: [blue, white]));
      await tester.pump();
      api.succeedOptions();
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard, Hours');

      tester.widget<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>).first).onChanged!(2);
      await tester.pump();
      for (final dot in tester.widgetList<ScheduleDayDot>(find.byType(ScheduleDayDot)).take(5).toList()) {
        dot.onPressed!();
      }
      await tester.pump();
      await tester.tap(find.text('Set hours per day'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard, hours per day');
      for (final field in tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList().asMap().entries) {
        field.value.onChanged!(field.key.isEven ? '08:00' : '16:00');
      }
      tester.widgetList<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>)).last.onChanged!(30);
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard, Rules');

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard, Review');
      expect(find.text('Save schedule'), findsOneWidget);
    });

    testWidgets('Groups page and Create group at $width px', (tester) async {
      final groups = FakeGroupManagementApi([groupOverview(1, 'Blue collar', employees: 64), groupOverview(2, 'White collar')]);
      final members = FakeGroupMembersApi()..pool.add(member(11, 'Fabian', 'Peeters', 'FPT'));
      final schedules = FakeSchedulesApi();
      await _pump(tester, width, GroupsScreen(groupsApi: groups, membersApi: members, schedulesApi: schedules));
      await tester.pump();
      schedules.succeedList([blue, white]);
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Groups');

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add group'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).first, 'Drivers');
      await tester.pump();
      await tester.tap(find.text('Fabian Peeters · FPT'));
      await tester.pump();
      _fitsTheWindow(tester, width, 'Create group, Group');
      await tester.ensureVisible(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pump();
      schedules.succeedOptions();
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Create group, Hours');
      for (final dot in tester.widgetList<ScheduleDayDot>(find.byType(ScheduleDayDot)).take(5).toList()) {
        dot.onPressed!();
      }
      await tester.pump();
      await tester.ensureVisible(find.text('Set hours per day'));
      await tester.tap(find.text('Set hours per day'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Create group, hours per day');
      await tester.ensureVisible(find.text('Use the same hours every day'));
      await tester.tap(find.text('Use the same hours every day'));
      await tester.pumpAndSettle();
      final times = tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList();
      times[0].onChanged!('08:00');
      times[1].onChanged!('16:30');
      tester.widgetList<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>)).last.onChanged!(30);
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Arrival tolerance'), findsOneWidget);
      _fitsTheWindow(tester, width, 'Create group, Rules');
      await tester.ensureVisible(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create group'), findsWidgets);
      _fitsTheWindow(tester, width, 'Create group, Review');
    });

    testWidgets('a group page at $width px', (tester) async {
      final groups = FakeGroupManagementApi([groupOverview(1, 'Blue collar', employees: 1)]);
      final members = FakeGroupMembersApi()
        ..byGroup[1] = [
          member(11, 'Fabian', 'Peeters', 'FPT', companies: ['Almeco', 'PCA'], groups: ['Blue collar', 'White collar']),
        ];
      final schedules = FakeSchedulesApi();
      await _pump(tester, width, GroupPage(groupId: 1, groupsApi: groups, membersApi: members, schedulesApi: schedules, scheduleSourceApi: FakeScheduleSourceApi()));
      await tester.pump();
      await tester.pump();
      schedules.succeedList([blue, white]);
      await tester.pumpAndSettle();

      _fitsTheWindow(tester, width, 'group page');
      expect(find.text('Fabian Peeters'), findsOneWidget);
    });

    testWidgets('Employees page and Add employee, every step, at $width px', (tester) async {
      final employees = FakeEmployeesApi();
      final groupsApi = FakeGroupsApi();
      final companiesApi = FakeCompaniesApi();
      final schedulesApi = FakeSchedulesApi();
      await _pump(tester, width, EmployeesScreen(api: employees, groupsApi: groupsApi, companiesApi: companiesApi, schedulesApi: schedulesApi, assignmentsApi: FakeEmployeeAssignmentsApi()));
      employees.succeed([
        employee(1, 'Disan', 'Ssebowa', 'SBW', groups: ['White collar', 'Blue collar']),
        employee(2, 'Thomas', 'Vermeulen', 'TVM', active: false),
      ]);
      await tester.pump();
      _fitsTheWindow(tester, width, 'Employees');

      await tester.tap(find.text('Add employee'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add employee, step 1');
      Finder field(String label) => find.descendant(of: find.widgetWithText(JitanTextField, label), matching: find.byType(TextField));
      await tester.enterText(field('First name'), 'Kevin');
      await tester.enterText(field('Last name'), 'De Vos');
      await tester.enterText(field('Employee code'), 'KDV');
      await tester.ensureVisible(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pump();
      companiesApi.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
      await tester.pump();
      groupsApi.succeed(const [GroupSummary(id: 3, name: 'White collar'), GroupSummary(id: 4, name: 'Blue collar')]);
      await tester.pump();
      schedulesApi.succeedList([blue, white]);
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add employee, step 2');
      tester.widget<JitanMultiSelectField<int>>(find.widgetWithText(JitanMultiSelectField<int>, 'Companies')).onChanged!([7]);
      await tester.pump();

      await tester.ensureVisible(find.widgetWithText(JitanPrimaryButton, 'Add employee').last);
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add employee').last);
      await tester.pump();
      employees.createSucceeds(employee(5, 'Kevin', 'De Vos', 'KDV'));
      await tester.pump();
      await tester.pump();
      employees.qrSucceeds('header.payload.signature', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Add employee, step 3 (onboarding QR)');
    });

    testWidgets('an employee and Reset access at $width px', (tester) async {
      final employees = FakeEmployeesApi();
      await _pump(tester, width, _detailsOpener(employees));
      await _openEmployee(tester, employees);
      await _settle(tester);
      employees.detailsSucceed(_activated);
      await _settle(tester);
      _fitsTheWindow(tester, width, 'an employee');

      await tester.ensureVisible(find.text('Reset account access'));
      await tester.tap(find.text('Reset account access'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Reset account access?');
    });

    testWidgets('Companies, groups and access, every tab, at $width px', (tester) async {
      final employees = FakeEmployeesApi();
      await _pump(tester, width, _detailsOpener(employees));
      await _openEmployee(tester, employees);
      await _settle(tester);
      employees.detailsSucceed(_activated);
      await _settle(tester);
      await tester.ensureVisible(find.text('Companies, groups and access'));
      await tester.tap(find.text('Companies, groups and access'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Companies, groups and access');
      for (final tab in ['Groups', 'Language', 'Access']) {
        await tester.ensureVisible(find.text(tab));
        await tester.pump();
        await tester.tap(find.text(tab));
        await _settle(tester);
        _fitsTheWindow(tester, width, 'Companies, groups and access · $tab');
      }
    });

    testWidgets('Deactivate an employee at $width px', (tester) async {
      final employees = FakeEmployeesApi();
      await _pump(tester, width, _detailsOpener(employees));
      await _openEmployee(tester, employees);
      await _settle(tester);
      employees.detailsSucceed(_activated);
      await _settle(tester);
      await tester.ensureVisible(find.text('Deactivate'));
      await tester.tap(find.text('Deactivate'));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Deactivate?');
    });

    testWidgets('the temporary QR at $width px', (tester) async {
      final employees = FakeEmployeesApi();
      await _pump(tester, width, _detailsOpener(employees));
      await _openEmployee(tester, employees);
      await _settle(tester);
      employees.detailsSucceed(
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
      await _settle(tester);
      await tester.ensureVisible(find.text('Show onboarding QR'));
      await tester.tap(find.text('Show onboarding QR'));
      await _settle(tester);
      employees.qrSucceeds('header.payload.signature', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Temporary onboarding QR');
    });

    testWidgets('the group dialogs at $width px', (tester) async {
      final groups = FakeGroupManagementApi([groupOverview(1, 'Blue collar', employees: 1), groupOverview(2, 'Empty')]);
      final members = FakeGroupMembersApi()
        ..byGroup[1] = [member(11, 'Fabian', 'Peeters', 'FPT')]
        ..pool.add(member(12, 'Kevin', 'De Vos', 'KDV', companies: ['PCA'], groups: ['White collar']));
      final schedules = FakeSchedulesApi();
      await _pump(tester, width, GroupPage(groupId: 1, groupsApi: groups, membersApi: members, schedulesApi: schedules, scheduleSourceApi: FakeScheduleSourceApi()));
      await tester.pump();
      await tester.pump();
      schedules.succeedList([blue, white]);
      await tester.pumpAndSettle();

      Future<void> open(String label, String what) async {
        await tester.ensureVisible(find.text(label).first);
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        _fitsTheWindow(tester, width, what);
        await tester.tapAt(const Offset(2, 2));
        await tester.pumpAndSettle();
        if (find.byType(JitanModal).evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('Close').last);
          await tester.pumpAndSettle();
        }
      }

      await open('Rename', 'Rename group');
      await open('Deactivate', 'Cannot deactivate group');
      await open('Add employees', 'Add employees');
      // Remove shows while the row is hovered.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Fabian Peeters')));
      await tester.pump();
      await open('Remove', 'Remove from group?');
    });

    testWidgets('a schedule and Remove break at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([blue, white]);
      await tester.pump();

      await tester.tap(find.text('Blue collar').first);
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'a schedule');
      await tester.tap(find.text('Remove break'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Remove break?');
    });

    testWidgets('Schedules with nothing to show at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([white]);
      await tester.pump();
      _fitsTheWindow(tester, width, 'No schedules yet');
    });
  }

  // Import employees: Ready, can't be used, preview with problems, done.
  for (final width in _widths) {
    testWidgets('Import employees, every state, at $width px', (tester) async {
      final api = FakeEmployeesApi();
      final files = <ChosenImportFile>[];
      final companies = FakeCompaniesApi();
      await _pump(
        tester,
        width,
        EmployeeImportScreen(api: api, companiesApi: companies, chooseFile: () async => files.removeAt(0), download: (_, _, _) {}),
      );
      await tester.pump();
      companies.succeed([company(7, 'Almeco')]);
      await tester.pump();
      await tester.pump();
      _fitsTheWindow(tester, width, 'Import, no company yet');
      tester.widget<JitanSelectField<int>>(find.byType(JitanSelectField<int>)).onChanged!(7);
      await tester.pump();
      _fitsTheWindow(tester, width, 'Import ready');

      Future<void> choose(String name, String csv, String button) async {
        files.add(ChosenImportFile(name: name, bytes: utf8.encode(csv)));
        await tester.tap(find.text(button).last);
        await tester.pump();
      }

      await choose('almeco.csv', 'First name\nA\n', 'Choose file');
      _fitsTheWindow(tester, width, "Import can't be used");

      final rows = StringBuffer('First name;Last name;Employee code;Groups;Phone\n');
      for (var i = 0; i < 12; i++) {
        rows.writeln('Chloé-Marie Alexandra;Vandenbroucke-Verstraete;CODE$i;"Blue collar; White collar; Drivers";+32 470 12 34 56');
      }
      await choose('a-rather-long-file-name-from-the-payroll-export.csv', '$rows', 'Choose another file');
      _fitsTheWindow(tester, width, 'Import reading');
      api.checkSucceeds(const [
        EmployeeImportProblem(row: 3, kind: EmployeeImportProblemKind.groupAmbiguous, detail: 'A group name that is rather long'),
      ]);
      await tester.pump();
      _fitsTheWindow(tester, width, 'Import preview');

      await tester.ensureVisible(find.text('Import 11 employees'));
      await tester.tap(find.text('Import 11 employees'));
      await tester.pump();
      _fitsTheWindow(tester, width, 'Importing');
      api.importSucceeds(const EmployeeImportResult(
        added: 11,
        skipped: [EmployeeImportProblem(row: 3, kind: EmployeeImportProblemKind.groupAmbiguous, detail: 'x')],
      ));
      await tester.pump();
      _fitsTheWindow(tester, width, 'Import done');
      expect(find.text('11 employees added to Almeco'), findsOneWidget);
    });
  }

  // Time records: the list with every status, and the day detail.
  for (final width in _widths) {
    testWidgets('Time records and the day detail at $width px', (tester) async {
      final api = FakeTimeRecordsApi();
      final companies = FakeCompaniesApi();
      await _pump(tester, width, TimeRecordsScreen(api: api, companiesApi: companies, today: () => DateTime(2026, 10, 22)));
      companies.succeed([company(7, 'Almeco')]);
      api.succeed([
        recordDay(
          1,
          'Alexandra-Marie',
          'Vandenbroucke-Verstraete',
          'AVV',
          DateTime.utc(2026, 10, 21),
          TimeRecordStatus.complete,
          start: recordTime('07:58', rounded: '08:00'),
          finish: recordTime('16:31', rounded: '16:30', method: TimeRecordMethod.manual, byHand: true, reason: 'Forgot to tap when leaving the workshop'),
          events: const [
            TimeRecordEvent(atLocal: '07:58', boundary: RegistrationBoundary.start, kind: TimeRecordEventKind.registered, active: true, method: TimeRecordMethod.qr),
            TimeRecordEvent(
              atLocal: '16:31',
              boundary: RegistrationBoundary.finish,
              kind: TimeRecordEventKind.correctionRequested,
              active: false,
              method: TimeRecordMethod.manual,
              reason: 'Forgot to tap when leaving the workshop',
            ),
          ],
        ),
        recordDay(2, 'Kevin', 'De Vos', 'KDV', DateTime.utc(2026, 10, 20), TimeRecordStatus.missingFinish, start: recordTime('08:03', rounded: '08:15')),
        recordDay(
          4,
          'Thomas',
          'Vermeulen',
          'TVM',
          DateTime.utc(2026, 10, 19),
          TimeRecordStatus.pendingReview,
          start: recordTime('07:01', rounded: '07:00'),
          finish: recordTime('15:32', rounded: '15:30'),
          pending: [
            TimeRecordPending(
              id: 55,
              boundary: RegistrationBoundary.start,
              requested: DateTime.utc(2026, 10, 19, 5),
              requestedLocal: '07:00',
              reason: 'Forgot to scan immediately after arriving at the van, the scanner was not working',
              roundedLocal: '07:00',
            ),
          ],
        ),
      ]);
      await tester.pump();
      await tester.pump();
      _fitsTheWindow(tester, width, 'Time records');

      await tester.ensureVisible(find.text('View').first);
      await tester.tap(find.text('View').first);
      await _settle(tester);
      _fitsTheWindow(tester, width, 'Time record day');

      await tester.ensureVisible(find.text('View detailed registration timeline'));
      await tester.tap(find.text('View detailed registration timeline'));
      await tester.pump();
      expect(find.text('Start registered · QR'), findsOneWidget);
      _fitsTheWindow(tester, width, 'Time record timeline');

      final correct = find.widgetWithText(JitanPrimaryButton, 'Correct time');
      await tester.ensureVisible(correct);
      await tester.tap(correct);
      await _settle(tester);
      expect(find.text('Correct time record'), findsOneWidget);
      _fitsTheWindow(tester, width, 'Correct time record');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tester.ensureVisible(find.text('Fix').first);
      await tester.tap(find.text('Fix').first);
      await _settle(tester);
      expect(find.text('Resolve missing finish'), findsOneWidget);
      _fitsTheWindow(tester, width, 'Resolve missing finish');
      await tester.tap(find.text('Mark as non-work'));
      await tester.pump();
      _fitsTheWindow(tester, width, 'Resolve: non-work');
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tester.ensureVisible(find.text('Review').first);
      await tester.tap(find.text('Review').first);
      await _settle(tester);
      expect(find.text('Review correction'), findsOneWidget);
      _fitsTheWindow(tester, width, 'Review correction');
      await tester.ensureVisible(find.text('Approve'));
      await tester.tap(find.text('Approve'));
      await tester.pump();
      api.writeSucceeds();
      await _settle(tester);
      expect(find.text('Correction saved'), findsOneWidget);
      _fitsTheWindow(tester, width, 'Correction saved');
    });
  }
}

