import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employees_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_employees_api.dart';
import '../support/fake_schedules_api.dart';

final _white = groupSchedule(3, 'White collar', work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'), breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30));
final _drivers = groupSchedule(4, 'Drivers', work: workDays([1, 2, 3, 4, 5], '06:00', '14:30'), breakDays: breaks([1, 2, 3, 4, 5], '10:00', 30));

/// Add employee from the Employees page (Figma prototype `153:970` →
/// `985:2` → `1233:2`): details → companies, groups, work schedule → the
/// onboarding QR → Finish setup, and the list reloads.
void main() {
  late FakeEmployeesApi employees;
  late FakeGroupsApi groups;
  late FakeCompaniesApi companies;
  late FakeSchedulesApi schedules;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    employees = FakeEmployeesApi();
    groups = FakeGroupsApi();
    companies = FakeCompaniesApi();
    schedules = FakeSchedulesApi();
    final current = CurrentCompanyController()..select(company(7, 'Almeco'));
    addTearDown(current.dispose);

    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: CurrentCompanyScope(
          controller: current,
          child: MaterialApp(
            theme: JitanTheme.web(),
            home: Scaffold(
              body: EmployeesScreen(api: employees, groupsApi: groups, companiesApi: companies, schedulesApi: schedules),
            ),
          ),
        ),
      ),
    );
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();
  }

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  Future<void> fillStep1(WidgetTester tester, {String code = 'KDV'}) async {
    await tester.tap(find.text('Add employee'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(field('Enter first name'), 'Kevin');
    await tester.enterText(field('Enter last name'), 'De Vos');
    await tester.enterText(field('Enter employee code'), code);
  }

  Future<void> continueToStep2(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue →'));
    await tester.pump();
    companies.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
    await tester.pump();
    groups.succeed(const [GroupSummary(id: 3, name: 'White collar'), GroupSummary(id: 4, name: 'Drivers')]);
    await tester.pump();
    schedules.succeedList([_white, _drivers]);
    await tester.pump();
  }

  Future<void> choose(WidgetTester tester, String fieldLabel, List<String> options) async {
    // Picking closes the list, so it is opened again for each option.
    for (final option in options) {
      await tester.tap(find.descendant(of: find.widgetWithText(JitanMultiSelectField<int>, fieldLabel), matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, option));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing, reason: 'the list closes on a pick');
    }
  }

  testWidgets('step 1 matches Figma: no Employee type; Continue checks the required fields', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Add employee'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (final text in ['Employee information', 'Work & assignments', 'Account activation', 'Personal information',
        'Contact details', 'First name', 'Last name', 'Employee code', 'Phone number', 'Email', 'Step 1 of 3']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Employee type'), findsNothing, reason: 'it is the employee group, chosen in step 2');

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue →'));
    await tester.pump();
    expect(find.text('Required.'), findsNWidgets(3));
    expect(companies.calls, [null], reason: 'only the Current company switcher; step 2 loads nothing yet');
  });

  testWidgets('the whole flow: details, assignments with work schedule, onboarding QR, Finish setup', (tester) async {
    await pumpPage(tester);
    await fillStep1(tester);
    await tester.enterText(field('Optional').last, 'kevin@example.com');
    await continueToStep2(tester);

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('No schedule available for the selected groups.'), findsOneWidget, reason: '1399:270, no group yet');
    expect(find.text('Select companies'), findsOneWidget, reason: 'the Employees filter never chooses');
    await choose(tester, 'Companies', ['Almeco', 'PCA']);
    await choose(tester, 'Employee groups', ['White collar', 'Drivers']);
    expect(find.text('Choose a group schedule'), findsOneWidget, reason: '1399:588, two groups with hours');

    await tester.tap(find.widgetWithText(JitanSelectField<int>, 'Work schedule'));
    await tester.pumpAndSettle();
    expect(find.text('White collar · Mon–Fri 08:00–16:30'), findsWidgets);
    await tester.tap(find.text('Drivers · Mon–Fri 06:00–14:30').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue →'));
    await tester.pump();
    final (companyId, request) = employees.creates.single;
    expect(companyId, 7);
    expect((request.firstName, request.lastName, request.code, request.email), ('Kevin', 'De Vos', 'KDV', 'kevin@example.com'));
    expect(request.companyIds, [7, 8]);
    expect(request.groupIds, [3, 4]);
    expect(request.scheduleGroupId, 4);

    employees.createSucceeds(employee(2, 'Kevin', 'De Vos', 'KDV', groups: ['White collar', 'Drivers']));
    await tester.pump();
    await tester.pump();
    expect(find.text('Activate employee account'), findsOneWidget);
    expect(find.descendant(of: find.byType(JitanModal), matching: find.text('Not activated')), findsOneWidget);
    expect(find.text('Almeco · PCA · White collar · Drivers'), findsOneWidget, reason: 'every chosen company');
    expect(find.widgetWithText(JitanSecondaryButton, 'Back'), findsNothing, reason: 'the employee exists now');
    expect(employees.qrRequests.single, (7, 2, TemporaryQrPurpose.onboarding));
    expect(find.text('Generating the onboarding QR…'), findsOneWidget, reason: '1399:747');
    employees.qrSucceeds('header.payload.signature', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(JitanQrCode), findsOneWidget);
    expect(find.text('header.payload.signature'), findsNothing, reason: 'a credential: shown only as a QR');

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Finish setup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(employees.calls.length, 2, reason: 'the list reloads');
  });

  testWidgets('a taken code brings HR back to step 1, under the code', (tester) async {
    await pumpPage(tester);
    await fillStep1(tester);
    await continueToStep2(tester);
    await choose(tester, 'Companies', ['Almeco']);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue →'));
    await tester.pump();
    employees.createFails(
      const ApiClientException.server(409, ApiError(code: ApiErrorCode.duplicateEmployeeCode, message: 'x', field: 'code')),
    );
    await tester.pump();

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('This employee code is already in use.'), findsOneWidget);
  });
}
