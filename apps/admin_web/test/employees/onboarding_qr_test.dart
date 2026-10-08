import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/employees_screen.dart';
import 'package:admin_web/src/employees/onboarding_qr_dialog.dart';
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

/// Employees → row → details → "Generate onboarding QR" → QR modal (EMP-08).
void main() {
  late FakeEmployeesApi employees;

  Future<void> openQr(WidgetTester tester) async {
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
              body: EmployeesScreen(api: employees, groupsApi: FakeGroupsApi(), assignmentsApi: FakeEmployeeAssignmentsApi()),
            ),
          ),
        ),
      ),
    );
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();
    await tester.tap(find.text('Disan Ssebowa'));
    await tester.pump(const Duration(milliseconds: 300));
    employees.detailsSucceed(_disan);
    await tester.pump();

    // Scoped to the modal: the table behind it has an 'Onboarding' column too.
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Onboarding')), findsOneWidget);
    await tester.tap(find.text('Generate onboarding QR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('requests the QR for that employee in the current company', (tester) async {
    await openQr(tester);

    expect(employees.qrRequests, [(7, 1)]);
    expect(find.text('Preparing the QR…'), findsOneWidget);
  });

  testWidgets('shows the QR, READY TO SCAN and the instruction; never the value as text', (tester) async {
    await openQr(tester);
    employees.qrSucceeds('n9Xq-2kLmPz8RtYw4VbC5dEf');
    await tester.pump();

    expect(find.text('Onboarding QR'), findsOneWidget);
    expect(find.text('Disan Ssebowa · Almeco'), findsOneWidget);
    expect(find.byType(JitanQrCode), findsOneWidget);
    expect(tester.widget<JitanQrCode>(find.byType(JitanQrCode)).data, 'n9Xq-2kLmPz8RtYw4VbC5dEf');
    expect(find.text('READY TO SCAN'), findsOneWidget);
    expect(find.text('Ask Disan to open Jitan and scan this QR.'), findsOneWidget);
    expect(find.textContaining('n9Xq'), findsNothing, reason: 'the credential is only drawn as a QR');
  });

  testWidgets('for an activated employee it is the personal Terminal QR, not an onboarding prompt', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeEmployeesApi();
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          home: Scaffold(
            body: OnboardingQrDialog(
              employeesApi: api,
              employee: const EmployeeDetails(
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
            ),
          ),
        ),
      ),
    );
    api.qrSucceeds('n9Xq-2kLmPz8RtYw4VbC5dEf');
    await tester.pump();

    expect(find.text('Personal QR'), findsOneWidget);
    expect(find.text('READY TO SCAN'), findsNothing);
    expect(find.text('Disan scans this QR at a Jitan Terminal to check in and out.'), findsOneWidget);
    expect(find.byType(JitanQrCode), findsOneWidget);
  });

  testWidgets('a failure shows an error with retry', (tester) async {
    await openQr(tester);
    employees.qrFails(const ApiClientException.network('offline'));
    await tester.pump();

    final retry = find.descendant(of: find.byType(Dialog).last, matching: find.text('Try again'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();
    expect(employees.qrRequests, hasLength(2));
  });
}
