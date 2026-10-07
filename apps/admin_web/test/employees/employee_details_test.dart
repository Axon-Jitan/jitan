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
              body: EmployeesScreen(api: employees, groupsApi: FakeGroupsApi()),
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
    expect(inModal('Generate onboarding QR'), findsOneWidget);
  });

  testWidgets('an activated employee: Account Activated, card offers the personal QR', (tester) async {
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
    expect(inModal('Show personal QR'), findsOneWidget);
    expect(inModal('Generate onboarding QR'), findsNothing);
    expect(
      inModal('Onboarding is complete. This is now the employee’s personal QR for Jitan Terminal.'),
      findsOneWidget,
    );
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
}
