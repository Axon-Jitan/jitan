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

final _white = groupSchedule(3, 'White collar', work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'), breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30));
final _drivers = groupSchedule(4, 'Drivers', work: workDays([1, 2, 3, 4, 5], '06:00', '14:30'), breakDays: breaks([1, 2, 3, 4, 5], '10:00', 30));

/// Add employee from the Employees page (Figma `1536:2` → `1536:389` →
/// `1536:569`): details → companies, groups and the hours → the onboarding
/// QR → Done, and the list reloads.
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
              body: EmployeesScreen(
                api: employees,
                groupsApi: groups,
                companiesApi: companies,
                schedulesApi: schedules,
                assignmentsApi: FakeEmployeeAssignmentsApi(),
              ),
            ),
          ),
        ),
      ),
    );
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();
  }

  /// The text box of the field labelled [label].
  Finder field(String label) => find.descendant(of: find.widgetWithText(JitanTextField, label), matching: find.byType(TextField));

  Future<void> openAdd(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add employee'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> fillStep1(WidgetTester tester, {String code = 'KDV'}) async {
    await openAdd(tester);
    await tester.enterText(field('First name'), 'Kevin');
    await tester.enterText(field('Last name'), 'De Vos');
    await tester.enterText(field('Employee code'), code);
  }

  Future<void> continueToStep2(WidgetTester tester, {List<CompanySummary>? all}) async {
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
    await tester.pump();
    companies.succeed(all ?? [company(7, 'Almeco'), company(8, 'PCA')]);
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

  Finder inModal(String text) => find.descendant(of: find.byType(JitanModal), matching: find.text(text));

  testWidgets('step 1 (1536:2): a slim progress, optional marks; a missing field says which, and clears as HR types', (tester) async {
    await pumpPage(tester);
    await openAdd(tester);

    expect(inModal('Step 1 of 3 · Details'), findsOneWidget);
    for (final gone in ['Employee information', 'Personal information', 'Contact details', 'Employee type', 'Continue →']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.text('Optional', findRichText: true), findsNothing, reason: 'part of the label');
    expect(find.textContaining('Optional', findRichText: true), findsNWidgets(2), reason: 'Phone and Email');

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
    await tester.pump();
    expect(find.text('Enter a first name.'), findsOneWidget);
    expect(find.text('Enter a last name.'), findsOneWidget);
    expect(find.text('Enter an employee code.'), findsOneWidget);

    await tester.enterText(field('First name'), 'K');
    await tester.pump();
    expect(find.text('Enter a first name.'), findsNothing, reason: 'it goes as soon as HR types');
    expect(find.text('Enter a last name.'), findsOneWidget, reason: 'the others stay');
    expect(companies.calls, [null, null], reason: 'the page (names in a pop-up) and the company filter; step 2 loads nothing yet');
  });

  testWidgets('a phone without its country code says so in full', (tester) async {
    await pumpPage(tester);
    await fillStep1(tester);
    await tester.enterText(find.widgetWithText(TextField, '+32 470 12 34 56'), '0470 12 34 56');
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
    await tester.pump();

    // The page's search, then first name, last name, code and phone.
    final error = tester.widget<TextField>(find.byType(TextField).at(4)).decoration!;
    expect(error.errorText, 'Start with + and the country code, like +32 470 12 34 56.');
    expect(error.errorMaxLines, greaterThan(1), reason: 'it wraps instead of being cut off');
  });

  testWidgets('the whole flow: details, work with the hours, the QR, Done', (tester) async {
    await pumpPage(tester);
    await fillStep1(tester);
    await tester.enterText(find.widgetWithText(TextField, 'name@company.be'), 'kevin@example.com');
    await continueToStep2(tester, all: [company(7, 'Almeco'), company(8, 'PCA'), company(9, 'Proceq', active: false)]);

    expect(inModal('Step 2 of 3 · Work'), findsOneWidget);
    expect(find.text('Select companies'), findsOneWidget, reason: 'the Employees filter never chooses');
    expect(inModal('Hours'), findsNothing, reason: 'nothing before a group is chosen');
    await tester.tap(find.descendant(of: find.widgetWithText(JitanMultiSelectField<int>, 'Companies'), matching: find.byType(InkWell)).first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Proceq'), findsNothing, reason: 'an inactive company can’t be chosen');
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await choose(tester, 'Companies', ['Almeco', 'PCA']);
    expect(find.text('Select companies'), findsNothing, reason: 'no hint beside the chosen ones');
    await choose(tester, 'Groups', ['White collar']);
    expect(inModal('Mon–Fri 08:00–16:30 · from White collar'), findsOneWidget, reason: 'one group: the hours, plainly');
    await choose(tester, 'Groups', ['Drivers']);
    expect(find.widgetWithText(JitanSelectField<int>, 'Hours from'), findsOneWidget, reason: 'two groups with hours: a choice');

    await tester.tap(find.widgetWithText(JitanSelectField<int>, 'Hours from'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon–Fri 06:00–14:30 · from Drivers').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add employee').last);
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
    expect(inModal('Kevin De Vos is added'), findsOneWidget, reason: '1536:569');
    expect(inModal('Step 3 of 3 · Set up'), findsOneWidget);
    expect(inModal('Back'), findsNothing, reason: 'the employee exists now');
    expect(employees.qrRequests.single, (7, 2, TemporaryQrPurpose.onboarding));
    employees.qrSucceeds('header.payload.signature', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
    await tester.pump();
    await tester.pump();
    expect(find.byType(JitanQrCode), findsOneWidget);
    expect(inModal('Ask Kevin to scan it in the Jitan app.'), findsOneWidget);
    expect(find.text('header.payload.signature'), findsNothing, reason: 'a credential: shown only as a QR');

    await tester.tap(find.widgetWithText(JitanSecondaryButton, 'Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(employees.calls.length, 2, reason: 'the list reloads');
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW'), employee(2, 'Kevin', 'De Vos', 'KDV')]);
    await tester.pump();
    expect(find.text('Kevin De Vos was added.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('step 3 closes by itself once the employee is set up', (tester) async {
    await pumpPage(tester);
    await fillStep1(tester);
    await continueToStep2(tester);
    await choose(tester, 'Companies', ['Almeco']);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add employee').last);
    await tester.pump();
    employees.createSucceeds(employee(2, 'Kevin', 'De Vos', 'KDV'));
    await tester.pump();
    await tester.pump();
    employees.qrSucceeds('qr', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    employees.detailsSucceed(
      const EmployeeDetails(
        id: 2,
        companyId: 7,
        companyName: 'Almeco',
        firstName: 'Kevin',
        lastName: 'De Vos',
        code: 'KDV',
        groups: [],
        phone: null,
        isActive: true,
        isActivated: true,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(inModal('Kevin De Vos is added'), findsNothing, reason: 'closed by itself');
    employees.succeed([employee(2, 'Kevin', 'De Vos', 'KDV', activated: true)]);
    await tester.pump();
    expect(find.text('Kevin De Vos is added and set up.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a taken code brings HR back to step 1, under the code', (tester) async {
    await pumpPage(tester);
    await fillStep1(tester);
    await continueToStep2(tester);
    await choose(tester, 'Companies', ['Almeco']);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add employee').last);
    await tester.pump();
    employees.createFails(
      const ApiClientException.server(409, ApiError(code: ApiErrorCode.duplicateEmployeeCode, message: 'x', field: 'code')),
    );
    await tester.pump();

    expect(inModal('Step 1 of 3 · Details'), findsOneWidget);
    expect(find.text('This employee code is already in use.'), findsOneWidget);
  });
}
