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

const _disan = EmployeeDetails(
  id: 1,
  companyId: 7,
  companyName: 'Almeco',
  firstName: 'Disan',
  lastName: 'Ssebowa',
  code: 'SBW',
  groups: ['White collar'],
  phone: null,
  isActive: true,
  isActivated: false,
);

/// Employee details from the Employees page: row click → modal (EMP-03).
void main() {
  late FakeEmployeesApi employees;

  Future<void> pumpPageAndOpen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    employees = FakeEmployeesApi();
    final current = CurrentCompanyController()..select(company(7, 'Almeco'));
    addTearDown(current.dispose);
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: CurrentCompanyScope(
          controller: current,
          child: MaterialApp(
            theme: JitanTheme.light(),
            home: Scaffold(
              body: EmployeesScreen(api: employees, groupsApi: FakeGroupsApi(), assignmentsApi: FakeEmployeeAssignmentsApi()),
            ),
          ),
        ),
      ),
    );
    employees.succeed([
      employee(1, 'Disan', 'Ssebowa', 'SBW', groups: ['White collar']),
    ]);
    await tester.pump();

    await tester.tap(find.text('Disan Ssebowa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder inModal(String text) => find.descendant(of: find.byType(Dialog), matching: find.text(text));

  testWidgets('clicking a row loads that employee for the current company', (tester) async {
    await pumpPageAndOpen(tester);

    expect(employees.detailRequests, [(7, 1)]);
    expect(inModal('Employee details'), findsOneWidget);
    expect(inModal('Loading employee…'), findsOneWidget);
  });

  testWidgets('shows the ERD-backed details; unknowns are "—", policy omitted', (tester) async {
    await pumpPageAndOpen(tester);
    employees.detailsSucceed(_disan);
    await tester.pump();

    expect(inModal('Disan Ssebowa'), findsOneWidget);
    expect(inModal('Almeco · Employee code SBW'), findsOneWidget);
    expect(inModal('White collar'), findsOneWidget);
    expect(inModal('Active'), findsOneWidget);
    for (final label in ['Employee type', 'Location', 'Phone number', 'Account', 'Status']) {
      expect(inModal(label), findsOneWidget, reason: label);
    }
    expect(inModal('Work policy'), findsNothing);
    // Location (GAP-11) and Phone (none).
    expect(inModal('—'), findsNWidgets(2));
    // Account field and Onboarding card status: not activated yet.
    expect(inModal('Not activated'), findsNWidgets(2));
    expect(inModal('Generate temporary QR'), findsOneWidget);
    expect(inModal('Generate a short-lived QR to set up this account. Terminal QR stays separate.'), findsOneWidget);
  });

  testWidgets('an activated employee: Account Activated, no QR is offered (the Terminal QR is never shown)', (tester) async {
    await pumpPageAndOpen(tester);
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
        isActivated: true,
      ),
    );
    await tester.pump();

    expect(inModal('Activated'), findsNWidgets(2));
    expect(inModal('Not activated'), findsNothing);
    expect(inModal('Generate temporary QR'), findsNothing);
    expect(inModal('Show personal QR'), findsNothing);
    expect(inModal('Onboarding is complete. If the employee is locked out, use Reset account access.'), findsOneWidget);
  });

  testWidgets('after a reset, "Generate temporary QR" opens the recovery QR, not onboarding', (tester) async {
    await pumpPageAndOpen(tester);
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
        accessResetPending: true,
      ),
    );
    await tester.pump();

    await tester.tap(inModal('Generate temporary QR'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(employees.qrRequests.single.$3, TemporaryQrPurpose.recovery);
  });

  testWidgets('a failure shows an error with retry', (tester) async {
    await pumpPageAndOpen(tester);
    employees.detailsFail(const ApiClientException.server(404, ApiError(code: ApiErrorCode.notFound, message: 'x')));
    await tester.pump();

    expect(inModal('Not found'), findsOneWidget);
    await tester.tap(inModal('Try again'));
    await tester.pump();
    expect(employees.detailRequests, hasLength(2));
  });

  group('Reset account access (HR/Admin-assisted recovery)', () {
    const activated = EmployeeDetails(
      id: 1,
      companyId: 7,
      companyName: 'Almeco',
      firstName: 'Disan',
      lastName: 'Ssebowa',
      code: 'SBW',
      groups: ['White collar'],
      phone: null,
      isActive: true,
      isActivated: true,
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shown bottom-left, disabled until the employee has activated', (tester) async {
      await pumpPageAndOpen(tester);
      employees.detailsSucceed(_disan);
      await settle(tester);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Reset account access'));
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Reset account access'), warnIfMissed: false);
      await settle(tester);
      expect(find.text('Reset account access?'), findsNothing);
    });

    testWidgets('asks to confirm and to verify the employee; Cancel changes nothing', (tester) async {
      await pumpPageAndOpen(tester);
      employees.detailsSucceed(activated);
      await settle(tester);

      await tester.tap(find.text('Reset account access'));
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

    testWidgets('confirmed: resets, then shows the temporary recovery QR, then reloads the details', (tester) async {
      await pumpPageAndOpen(tester);
      employees.detailsSucceed(activated);
      await settle(tester);
      await tester.tap(find.text('Reset account access'));
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
      expect(find.text('Temporary password recovery QR'), findsOneWidget);
      expect(find.text('This QR is not the employee’s permanent Terminal QR.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(employees.detailRequests, hasLength(2), reason: 'reloaded from the server');
      employees.detailsSucceed(_disan);
      await settle(tester);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Reset account access'));
      expect(button.onPressed, isNull, reason: 'now not activated');
    });

    testWidgets('a refused reset is explained in the dialog, which stays open', (tester) async {
      await pumpPageAndOpen(tester);
      employees.detailsSucceed(activated);
      await settle(tester);
      await tester.tap(find.text('Reset account access'));
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
