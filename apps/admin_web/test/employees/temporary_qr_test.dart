import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employees_screen.dart';
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
import '../support/fake_schedules_api.dart';

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

/// Employees → row → the employee → "Show onboarding QR" → the QR pop-up.
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
              body: EmployeesScreen(
                api: employees,
                groupsApi: FakeGroupsApi(),
                companiesApi: FakeCompaniesApi(),
                schedulesApi: FakeSchedulesApi(),
                assignmentsApi: FakeEmployeeAssignmentsApi(),
              ),
            ),
          ),
        ),
      ),
    );
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW', companyIds: [7])]);
    await tester.pump();
    await tester.tap(find.text('Disan Ssebowa'));
    await tester.pump(const Duration(milliseconds: 300));
    employees.detailsSucceed(_disan);
    await tester.pump();
    await tester.tap(find.text('Show onboarding QR'));
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

  testWidgets('onboarding: Figma 1532:181, counts down once, never shows the value as text', (tester) async {
    var now = _now;
    await openAlone(tester, TemporaryQrPurpose.onboarding, () => now);
    employees.qrSucceeds('header.payload.signature', expiresAt: _now.add(const Duration(minutes: 10)));
    await tester.pump();

    expect(find.text('Onboarding QR'), findsOneWidget);
    expect(find.text('Disan Ssebowa · Almeco'), findsOneWidget);
    expect(tester.widget<JitanQrCode>(find.byType(JitanQrCode)).data, 'header.payload.signature');
    expect(find.text('Ask Disan to scan it in the Jitan app.'), findsOneWidget);
    expect(find.text('Works once · Expires in 10:00'), findsOneWidget);
    expect(find.text('Make a new QR'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    for (final gone in ['VALID FOR 10 MIN', 'A replacement QR invalidates the previous one.']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.textContaining('MySQL'), findsNothing);
    expect(find.textContaining('signature'), findsNothing, reason: 'only drawn as a QR');

    now = _now.add(const Duration(minutes: 3, seconds: 25));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Works once · Expires in 06:35'), findsOneWidget);
  });

  testWidgets('expired: Figma 1532:1363, in the same pop-up; Make a new QR replaces it', (tester) async {
    var now = _now;
    await openAlone(tester, TemporaryQrPurpose.onboarding, () => now);
    employees.qrSucceeds('first', expiresAt: _now.add(const Duration(minutes: 10)));
    await tester.pump();

    now = _now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(JitanQrCode), findsNothing, reason: 'an expired code is no longer drawn');
    expect(find.text('Onboarding QR'), findsOneWidget, reason: 'the same pop-up');
    expect(find.text('This QR has expired.'), findsOneWidget);
    expect(find.text('Make a new one to continue.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Make a new QR'));
    await tester.pump();
    employees.qrSucceeds('second', expiresAt: now.add(const Duration(minutes: 10)));
    await tester.pump();
    expect(employees.qrRequests, hasLength(2));
    expect(tester.widget<JitanQrCode>(find.byType(JitanQrCode)).data, 'second');
  });

  testWidgets('recovery: Figma 1532:772, the same layout', (tester) async {
    await openAlone(tester, TemporaryQrPurpose.recovery, () => _now);
    employees.qrSucceeds('recovery', expiresAt: _now.add(const Duration(minutes: 10)));
    await tester.pump();

    expect(employees.qrRequests.single.$3, TemporaryQrPurpose.recovery);
    expect(find.text('Recovery QR'), findsOneWidget);
    expect(find.text('Ask Disan to scan it in the Jitan app to set a new password.'), findsOneWidget);
    expect(find.text('Works once · Expires in 10:00'), findsOneWidget);
    expect(find.textContaining('Terminal QR'), findsNothing);
  });

  testWidgets('closes by itself once the employee has finished, and the page says so', (tester) async {
    await openFromDetails(tester);
    employees.qrSucceeds('qr', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)));
    await tester.pump();
    expect(find.text('Onboarding QR'), findsOneWidget);
    final looksBefore = employees.detailRequests.length;

    await tester.pump(const Duration(seconds: 3));
    expect(employees.detailRequests, hasLength(looksBefore + 1), reason: 'looks every 3 s');
    employees.detailsSucceed(_disan); // not set up yet
    await tester.pump();
    expect(find.text('Onboarding QR'), findsOneWidget, reason: 'still waiting');

    await tester.pump(const Duration(seconds: 3));
    employees.detailsSucceed(
      const EmployeeDetails(
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
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Onboarding QR'), findsNothing, reason: 'closed by itself');
    expect(find.text('Disan Ssebowa is set up.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
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

  test('the controller: a failed look changes nothing; a password means used', () async {
    final api = FakeEmployeesApi();
    final controller = TemporaryQrController(
      api: api,
      companyId: 7,
      userId: 1,
      purpose: TemporaryQrPurpose.onboarding,
      clock: () => _now,
      watchEvery: const Duration(milliseconds: 10),
    );
    api.qrSucceeds('secret', expiresAt: _now.add(const Duration(minutes: 10)));
    await pumpEventQueue();

    await Future<void>.delayed(const Duration(milliseconds: 15));
    api.detailsFail(const ApiClientException.network('offline'));
    await pumpEventQueue();
    expect(controller.used, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 15));
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
        isActivated: true,
      ),
    );
    await pumpEventQueue();
    expect(controller.used, isTrue);
    controller.dispose();
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
