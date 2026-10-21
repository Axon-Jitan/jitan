import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employee_details_dialog.dart';
import 'package:admin_web/src/employees/temporary_qr/temporary_qr_controller.dart';
import 'package:admin_web/src/employees/temporary_qr/temporary_qr_dialog.dart';
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

final _now = DateTime.utc(2026, 10, 8, 12);

/// Employees → row → details → "Generate temporary QR" → temporary QR modal.
void main() {
  late FakeEmployeesApi employees;

  Future<void> openFromDetails(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
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
              // Employee details has no way in from a row in V1 (EMP-DETAILS-V2):
              // the test opens it directly.
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showEmployeeDetailsDialog(
                    context,
                    employeesApi: employees,
                    assignmentsApi: FakeEmployeeAssignmentsApi(),
                    companyId: 7,
                    userId: 1,
                  ),
                  child: const Text('open details'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open details'));
    await tester.pump(const Duration(milliseconds: 300));
    employees.detailsSucceed(_disan);
    await tester.pump();
    await tester.tap(find.text('Generate temporary QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// The modal on its own, with a controllable clock.
  Future<void> openAlone(WidgetTester tester, TemporaryQrPurpose purpose, DateTime Function() clock) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    employees = FakeEmployeesApi();
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.light(),
          home: Scaffold(body: TemporaryQrDialog(employeesApi: employees, employee: _disan, purpose: purpose, clock: clock)),
        ),
      ),
    );
  }

  testWidgets('generates an onboarding QR for that employee in the current company', (tester) async {
    await openFromDetails(tester);

    expect(employees.qrRequests, [(7, 1, TemporaryQrPurpose.onboarding)]);
    expect(find.text('Generating a temporary QR…'), findsOneWidget);
  });

  testWidgets('onboarding: matches Figma, counts down, never shows the value as text', (tester) async {
    var now = _now;
    await openAlone(tester, TemporaryQrPurpose.onboarding, () => now);
    employees.qrSucceeds('header.payload.signature', expiresAt: _now.add(const Duration(minutes: 10)));
    await tester.pump();

    expect(find.text('Temporary onboarding QR'), findsOneWidget);
    expect(find.text('Disan Ssebowa · Almeco'), findsOneWidget);
    expect(tester.widget<JitanQrCode>(find.byType(JitanQrCode)).data, 'header.payload.signature');
    expect(find.text('VALID FOR 10 MIN'), findsOneWidget);
    expect(find.text('Ask the employee to scan this temporary QR in Jitan.'), findsOneWidget);
    expect(find.text('Expires in 10:00  ·  Single-use  ·  Not stored in MySQL'), findsOneWidget);
    expect(find.text('A replacement QR invalidates the previous one.'), findsOneWidget);
    expect(find.textContaining('signature'), findsNothing, reason: 'only drawn as a QR');

    now = _now.add(const Duration(minutes: 3, seconds: 25));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expires in 06:35  ·  Single-use  ·  Not stored in MySQL'), findsOneWidget);
  });

  testWidgets('expired: Figma 207:215 "Temporary QR expired"; Generate new QR replaces it', (tester) async {
    var now = _now;
    await openAlone(tester, TemporaryQrPurpose.onboarding, () => now);
    employees.qrSucceeds('first', expiresAt: _now.add(const Duration(minutes: 10)));
    await tester.pump();

    now = _now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(JitanQrCode), findsNothing, reason: 'an expired code is no longer drawn');
    expect(find.text('Temporary QR expired'), findsOneWidget);
    expect(find.text('This code is no longer valid. Generate a new one to continue.'), findsOneWidget);
    expect(find.text('Expired or already used'), findsOneWidget);
    expect(find.text('No password or account changes were made by this screen.'), findsOneWidget);

    await tester.tap(find.text('Generate new QR'));
    await tester.pump();
    employees.qrSucceeds('second', expiresAt: now.add(const Duration(minutes: 10)));
    await tester.pump();
    expect(employees.qrRequests, hasLength(2));
    expect(tester.widget<JitanQrCode>(find.byType(JitanQrCode)).data, 'second');
    expect(find.text('Temporary onboarding QR'), findsOneWidget);
  });

  testWidgets('recovery: matches Figma 207:111 with Close and Generate new QR', (tester) async {
    await openAlone(tester, TemporaryQrPurpose.recovery, () => _now);
    employees.qrSucceeds('recovery', expiresAt: _now.add(const Duration(minutes: 10)));
    await tester.pump();

    expect(employees.qrRequests.single.$3, TemporaryQrPurpose.recovery);
    expect(find.text('Temporary password recovery QR'), findsOneWidget);
    expect(find.text('Generate this only after HR/Admin has verified the employee and reset access.'), findsOneWidget);
    expect(find.text('Expires in 10:00 · Single-use · Recovery only'), findsOneWidget);
    expect(find.text('This QR is not the employee’s permanent Terminal QR.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Generate new QR'), findsOneWidget);
  });

  testWidgets('a failure shows an error with retry', (tester) async {
    await openFromDetails(tester);
    employees.qrFails(const ApiClientException.network('offline'));
    await tester.pump();

    final retry = find.descendant(of: find.byType(Dialog).last, matching: find.text('Try again'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();
    expect(employees.qrRequests, hasLength(2));
  });

  test('the controller drops the value when disposed', () async {
    final api = FakeEmployeesApi();
    final controller = TemporaryQrController(api: api, companyId: 7, userId: 1, purpose: TemporaryQrPurpose.onboarding, clock: () => _now);
    api.qrSucceeds('secret', expiresAt: _now.add(const Duration(minutes: 10)));
    await pumpEventQueue();
    expect(controller.qr?.qrCode, 'secret');

    controller.dispose();

    expect(controller.qr, isNull);
  });
}
