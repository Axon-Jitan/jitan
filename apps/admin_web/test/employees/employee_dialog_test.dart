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

EmployeeDetails _details({bool activated = false, bool resetPending = false, String? phone}) => EmployeeDetails(
  id: 1,
  companyId: 7,
  companyName: 'Almeco',
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: const ['White collar'],
  phone: phone,
  isActive: true,
  isActivated: activated,
  accessResetPending: resetPending,
);

/// An employee's pop-up from a row of Employees (Figma `1531:259`, not set
/// up yet `1531:459`).
void main() {
  late FakeEmployeesApi employees;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The page with one employee (in Almeco and PCA), opened from its row.
  Future<void> open(WidgetTester tester, {bool activated = false, CompanySummary? selected}) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    employees = FakeEmployeesApi();
    final companies = FakeCompaniesApi();
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
                api: employees,
                groupsApi: FakeGroupsApi(),
                companiesApi: companies,
                schedulesApi: FakeSchedulesApi(),
                assignmentsApi: FakeEmployeeAssignmentsApi(),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < companies.calls.length; i++) {
      companies.succeed([company(7, 'Almeco'), company(8, 'PCA'), company(9, 'Proceq')], index: i);
    }
    employees.succeed([
      employee(1, 'Disan', 'Ssebowa', 'SBW', groups: ['White collar'], activated: activated, companyIds: [7, 8]),
    ]);
    await settle(tester);
    await tester.tap(find.text('Disan Ssebowa'));
    await settle(tester);
  }

  Finder inModal(String text) => find.descendant(of: find.byType(Dialog), matching: find.text(text));

  testWidgets('a row opens the employee, asked through one of their companies with no company chosen', (tester) async {
    await open(tester);
    expect(employees.detailRequests, [(7, 1)]);
    expect(inModal('Loading the employee…'), findsOneWidget);

    employees.detailsSucceed(_details(phone: '+32 470 12 34 56'));
    await settle(tester);

    expect(inModal('Disan Ssebowa'), findsOneWidget);
    expect(inModal('SBW · Not set up'), findsOneWidget);
    for (final (label, value) in [
      ('Companies', 'Almeco, PCA'),
      ('Type', 'White collar'),
      ('Phone', '+32 470 12 34 56'),
      ('Account', 'Not set up'),
    ]) {
      expect(inModal(label), findsOneWidget, reason: label);
      expect(inModal(value), findsOneWidget, reason: value);
    }
    expect(inModal('Proceq'), findsNothing, reason: 'only their companies');
  });

  testWidgets('with a company chosen, the details are asked through it', (tester) async {
    await open(tester, selected: company(8, 'PCA'));
    expect(employees.detailRequests, [(8, 1)]);
  });

  testWidgets('not set up: Show onboarding QR, no Reset account access', (tester) async {
    await open(tester);
    employees.detailsSucceed(_details());
    await settle(tester);

    expect(inModal('Reset account access'), findsNothing, reason: 'nothing to reset yet: not offered at all');
    await tester.tap(inModal('Show onboarding QR'));
    await settle(tester);
    expect(employees.qrRequests, [(7, 1, TemporaryQrPurpose.onboarding)]);
  });

  testWidgets('after a reset: Show recovery QR, which opens the recovery QR', (tester) async {
    await open(tester);
    employees.detailsSucceed(_details(resetPending: true));
    await settle(tester);

    expect(inModal('Show onboarding QR'), findsNothing);
    await tester.tap(inModal('Show recovery QR'));
    await settle(tester);
    expect(employees.qrRequests, [(7, 1, TemporaryQrPurpose.recovery)]);
  });

  testWidgets('a failure shows an error with retry', (tester) async {
    await open(tester);
    employees.detailsFail(const ApiClientException.network('offline'));
    await settle(tester);

    expect(inModal('Try again'), findsOneWidget);
    await tester.tap(inModal('Try again'));
    await settle(tester);
    expect(employees.detailRequests, hasLength(2));
  });

  testWidgets('Companies and groups opens the assignments', (tester) async {
    await open(tester);
    employees.detailsSucceed(_details(activated: true));
    await settle(tester);

    await tester.tap(inModal('Companies and groups'));
    await tester.pumpAndSettle();
    expect(find.text('Disan Ssebowa'), findsWidgets);
    expect(inModal('Account'), findsNothing, reason: 'the employee pop-up gave way to the assignments');
  });

  group('Remove employee', () {
    testWidgets('asks first, then the list reloads once the server confirms', (tester) async {
      await open(tester);
      employees.detailsSucceed(_details());
      await settle(tester);

      await tester.tap(inModal('Remove employee'));
      await settle(tester);
      expect(find.text('Remove employee?'), findsOneWidget, reason: '238:3853');
      expect(find.text('Are you sure you want to remove Disan Ssebowa?'), findsOneWidget);
      expect(employees.removes, isEmpty, reason: 'nothing before the confirmation');

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
      await tester.pump();
      expect(employees.removes, [(7, 1)], reason: 'no company filter: one of the companies of the employee');
      expect(find.text('Disan Ssebowa was removed.'), findsNothing, reason: 'no success before the server confirms');

      employees.removeSucceeds();
      await settle(tester);
      expect(find.text('Remove employee?'), findsNothing);
      expect(find.text('Disan Ssebowa was removed.'), findsOneWidget);
      expect(employees.calls, hasLength(2), reason: 'the list reloads');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a refusal stays in the dialog and says why', (tester) async {
      await open(tester);
      employees.detailsSucceed(_details());
      await settle(tester);
      await tester.tap(inModal('Remove employee'));
      await settle(tester);

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
      await tester.pump();
      employees.removeFails(const ApiClientException.network('offline'));
      await tester.pumpAndSettle();

      expect(find.text('Remove employee?'), findsOneWidget);
      expect(employees.calls, hasLength(1), reason: 'nothing changed: no reload');
    });
  });

  group('Reset account access (HR/Admin-assisted recovery)', () {
    testWidgets('asks to confirm and to verify the employee; Cancel changes nothing', (tester) async {
      await open(tester, activated: true);
      employees.detailsSucceed(_details(activated: true));
      await settle(tester);
      expect(inModal('Show onboarding QR'), findsNothing, reason: 'set up: no onboarding QR');

      await tester.tap(inModal('Reset account access'));
      await settle(tester);

      expect(find.text('Reset account access?'), findsOneWidget);
      expect(find.textContaining('Use this only after verifying the employee.'), findsOneWidget);
      for (final effect in [
        '• sign out active sessions',
        '• clear the current password hash',
        '• allow recovery with a temporary recovery QR',
        '• keep the employee’s Terminal QR unchanged',
        'After reset: generate a temporary recovery QR for the employee. Do not use the Terminal QR.',
      ]) {
        expect(find.text(effect), findsOneWidget);
      }

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(employees.resetRequests, isEmpty);
      expect(find.text('Reset account access?'), findsNothing);
    });

    testWidgets('confirmed: resets, shows the temporary recovery QR, then the list reloads', (tester) async {
      await open(tester, activated: true);
      employees.detailsSucceed(_details(activated: true));
      await settle(tester);
      await tester.tap(inModal('Reset account access'));
      await settle(tester);

      await tester.tap(find.text('Reset access'));
      await tester.pump();
      expect(employees.resetRequests, [(7, 1)]);
      employees.resetSucceeds();
      await settle(tester);

      expect(find.text('Reset account access?'), findsNothing);
      expect(find.text('Access reset for Disan Ssebowa. Show them the temporary recovery QR.'), findsOneWidget);
      expect(employees.qrRequests, [(7, 1, TemporaryQrPurpose.recovery)]);
      employees.qrSucceeds('recovery-token', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
      await tester.pump();
      expect(find.text('Recovery QR'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(employees.calls, hasLength(2), reason: 'the list reloads: now not set up');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a refused reset is explained in the dialog, which stays open', (tester) async {
      await open(tester, activated: true);
      employees.detailsSucceed(_details(activated: true));
      await settle(tester);
      await tester.tap(inModal('Reset account access'));
      await settle(tester);

      await tester.tap(find.text('Reset access'));
      await tester.pump();
      employees.resetFails(
        const ApiClientException.server(409, ApiError(code: ApiErrorCode.accountNotActivated, message: 'x')),
      );
      await settle(tester);

      expect(find.text('This employee hasn’t set up Jitan yet, so there is no access to reset.'), findsOneWidget);
      expect(find.text('Reset account access?'), findsWidgets);
    });
  });
}
