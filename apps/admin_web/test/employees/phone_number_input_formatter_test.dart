import 'package:admin_web/src/employees/add_employee_controller.dart';
import 'package:admin_web/src/employees/phone_number_input_formatter.dart';
import 'package:admin_web/src/l10n/admin_text_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_employees_api.dart';
import '../support/fake_schedules_api.dart';

void main() {
  testWidgets('the phone field keeps only + and digits and arranges them as typed', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TextField(controller: controller, inputFormatters: const [PhoneNumberInputFormatter()])),
    ));

    await tester.enterText(find.byType(TextField), '+32470123456');
    expect(controller.text, '+32 470 12 34 56');

    await tester.enterText(find.byType(TextField), 'cbc');
    expect(controller.text, '', reason: 'letters are not typed');

    await tester.enterText(find.byType(TextField), '+32 47a0');
    expect(controller.text, startsWith('+32 470'));
  });

  test('step 1 refuses a phone without country code; a good one is sent in Jitan\'s form', () async {
    final employees = FakeEmployeesApi();
    final controller = AddEmployeeController(
      employeesApi: employees,
      groupsApi: FakeGroupsApi(),
      companiesApi: FakeCompaniesApi(),
      schedulesApi: FakeSchedulesApi(),
    );
    addTearDown(controller.dispose);
    NewEmployeeInput input(String phone) => (firstName: 'A', lastName: 'B', code: 'C', phone: phone, email: '');

    controller.next(input('0470 12 34 56'));
    expect(controller.fieldErrors, {CreateEmployeeRequest.fieldPhone: AdminTextKeys.employeeFieldErrorPhoneCountryCode});
    controller.next(input('+3247'));
    expect(controller.fieldErrors, {CreateEmployeeRequest.fieldPhone: AdminTextKeys.employeeFieldErrorPhoneInvalid});
    controller.next(input('+32abc'));
    expect(controller.fieldErrors, {CreateEmployeeRequest.fieldPhone: AdminTextKeys.employeeFieldErrorPhoneLetters});

    controller.next(input('+32470123456'));
    expect(controller.fieldErrors, isEmpty);
    expect(controller.step, AddEmployeeStep.assignments);
  });
}
