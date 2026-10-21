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

/// Add employee from the Employees page: open → fill → create → list reloads.
void main() {
  late FakeEmployeesApi employees;
  late FakeGroupsApi groups;

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    employees = FakeEmployeesApi();
    groups = FakeGroupsApi();
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
              body: EmployeesScreen(api: employees, groupsApi: groups),
            ),
          ),
        ),
      ),
    );
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await tester.pump();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('Add employee'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    groups.succeed(const [GroupSummary(id: 3, name: 'White collar'), GroupSummary(id: 4, name: 'Blue collar')]);
    await tester.pump();
  }

  Finder field(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(JitanTextField)),
    matching: find.byType(TextField),
  );

  testWidgets('shows the modal with only the ERD-backed fields', (tester) async {
    await pumpPage(tester);
    await openDialog(tester);

    // Scoped to the modal: the table behind it has its own "Location" header.
    Finder inModal(String text) => find.descendant(of: find.byType(Dialog), matching: find.text(text));

    expect(inModal('Create the employee record.'), findsOneWidget);
    for (final label in ['First name', 'Last name', 'Employee code', 'Employee type', 'Phone number']) {
      expect(inModal(label), findsOneWidget, reason: label);
    }
    expect(inModal('Location'), findsNothing, reason: 'ERD GAP-11');
    expect(inModal('Work policy'), findsNothing, reason: 'PRODUCT-CLARIFY-EMPLOYEE-POLICY');
  });

  testWidgets('creates the employee, closes, reloads the list and confirms', (tester) async {
    await pumpPage(tester);
    await openDialog(tester);

    await tester.enterText(field('First name'), 'Kevin');
    await tester.enterText(field('Last name'), 'De Vos');
    await tester.enterText(field('Employee code'), 'KDV');
    await tester.tap(find.text('No type'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('White collar').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Create employee'));
    await tester.pump();

    final (companyId, request) = employees.creates.single;
    expect(companyId, 7);
    expect(request.code, 'KDV');
    expect(request.groupIds, [3]);

    employees.createSucceeds(employee(2, 'Kevin', 'De Vos', 'KDV', groups: ['White collar']));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Create the employee record.'), findsNothing, reason: 'modal closed');
    expect(employees.calls, hasLength(2), reason: 'list reloaded after the server confirmed');
    employees.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW'), employee(2, 'Kevin', 'De Vos', 'KDV')]);
    await tester.pump();

    expect(find.text('Kevin De Vos'), findsOneWidget);
    expect(find.text('Kevin De Vos was added.'), findsOneWidget);
  });

  testWidgets('a duplicate code keeps the modal open with the error on the code field', (tester) async {
    await pumpPage(tester);
    await openDialog(tester);

    await tester.enterText(field('First name'), 'X');
    await tester.enterText(field('Last name'), 'Y');
    await tester.enterText(field('Employee code'), 'SBW');
    await tester.tap(find.text('Create employee'));
    await tester.pump();
    employees.createFails(
      const ApiClientException.server(
        409,
        ApiError(code: ApiErrorCode.duplicateEmployeeCode, message: 'x', field: 'code'),
      ),
    );
    await tester.pump();

    expect(find.text('This employee code is already in use.'), findsOneWidget);
    expect(find.text('Create the employee record.'), findsOneWidget, reason: 'still open');
    expect(employees.calls, hasLength(1), reason: 'no reload without a successful create');
  });

  testWidgets('required fields are flagged before anything is sent', (tester) async {
    await pumpPage(tester);
    await openDialog(tester);

    await tester.tap(find.text('Create employee'));
    await tester.pump();

    expect(find.text('Required.'), findsNWidgets(3));
    expect(employees.creates, isEmpty);
  });

  testWidgets('a network failure shows a form error and the form stays usable', (tester) async {
    await pumpPage(tester);
    await openDialog(tester);

    await tester.enterText(field('First name'), 'X');
    await tester.enterText(field('Last name'), 'Y');
    await tester.enterText(field('Employee code'), 'Z1');
    await tester.tap(find.text('Create employee'));
    await tester.pump();
    employees.createFails(const ApiClientException.network('offline'));
    await tester.pump();

    expect(find.text('Can’t reach Jitan'), findsOneWidget);
    expect(find.text('Create employee'), findsOneWidget, reason: 'button back, can retry');
  });
}
