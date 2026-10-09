import 'package:admin_web/src/employees/add_employee_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_employees_api.dart';

NewEmployeeInput _input({
  String firstName = 'Disan',
  String lastName = 'Ssebowa',
  String code = 'SBW',
  int? groupId,
  String phone = '',
}) => (firstName: firstName, lastName: lastName, code: code, groupId: groupId, phone: phone);

ApiClientException _server(int status, String code, {String? field}) =>
    ApiClientException.server(status, ApiError(code: code, message: 'x', field: field));

void main() {
  late FakeEmployeesApi employees;
  late FakeGroupsApi groups;
  late AddEmployeeController controller;

  setUp(() {
    employees = FakeEmployeesApi();
    groups = FakeGroupsApi();
    controller = AddEmployeeController(employeesApi: employees, groupsApi: groups, companyId: 7);
  });

  tearDown(() => controller.dispose());

  test('loads the employee types', () async {
    final load = controller.loadGroups();
    expect(controller.groups, isA<GroupOptionsLoading>());

    groups.succeed(const [GroupSummary(id: 3, name: 'White collar')]);
    await load;

    expect((controller.groups as GroupOptionsLoaded).groups.single.name, 'White collar');
  });

  test('types failing to load does not block creating', () async {
    final load = controller.loadGroups();
    groups.fail(const ApiClientException.network('offline'));
    await load;

    expect(controller.groups, isA<GroupOptionsFailed>());
  });

  test('blank required fields are flagged without calling the server', () async {
    final result = await controller.submit(_input(firstName: ' ', code: ''));

    expect(result, isNull);
    expect(controller.fieldErrors.keys, unorderedEquals(['firstName', 'code']));
    expect(employees.creates, isEmpty);
  });

  test('values longer than the database allows are flagged without calling the server', () async {
    final result = await controller.submit(
      _input(
        firstName: 'x' * (CreateEmployeeRequest.maxFirstNameLength + 1),
        code: 'x' * CreateEmployeeRequest.maxCodeLength,
        phone: '1' * (CreateEmployeeRequest.maxPhoneLength + 1),
      ),
    );

    expect(result, isNull);
    expect(controller.fieldErrors, {
      'firstName': 'employee.field.error.tooLong',
      'phone': 'employee.field.error.tooLong',
    });
    expect(employees.creates, isEmpty);
  });

  test('a server validation error on a filled-in field is shown as too long', () async {
    final submit = controller.submit(_input(lastName: 'Ssebowa'));
    employees.createFails(_server(400, ApiErrorCode.validationFailed, field: 'lastName'));
    await submit;

    expect(controller.fieldErrors, {'lastName': 'employee.field.error.tooLong'});
  });

  test('sends trimmed values for the current company; empty phone becomes null', () async {
    final submit = controller.submit(_input(firstName: ' Disan ', code: ' SBW ', groupId: 3, phone: '  '));
    expect(controller.submitting, isTrue);

    employees.createSucceeds(employee(5, 'Disan', 'Ssebowa', 'SBW'));
    final created = await submit;

    expect(created?.id, 5);
    expect(controller.submitting, isFalse);
    final (companyId, request) = employees.creates.single;
    expect(companyId, 7);
    expect(request.firstName, 'Disan');
    expect(request.code, 'SBW');
    expect(request.groupId, 3);
    expect(request.phone, isNull);
  });

  test('a second submit while busy is ignored (no double create)', () async {
    final first = controller.submit(_input());
    final second = await controller.submit(_input());

    expect(second, isNull);
    expect(employees.creates, hasLength(1));
    employees.createSucceeds(employee(5, 'Disan', 'Ssebowa', 'SBW'));
    await first;
  });

  test('a duplicate code is shown on the code field', () async {
    final submit = controller.submit(_input());
    employees.createFails(_server(409, ApiErrorCode.duplicateEmployeeCode, field: 'code'));

    expect(await submit, isNull);
    expect(controller.fieldErrors, {'code': 'employee.field.error.duplicateCode'});
    expect(controller.formFailure, isNull);
  });

  test('a server validation error lands on its field', () async {
    final submit = controller.submit(_input(groupId: 9));
    employees.createFails(_server(400, ApiErrorCode.validationFailed, field: 'groupId'));
    await submit;

    expect(controller.fieldErrors, {'groupId': 'employee.field.error.invalidType'});
  });

  test('other failures become a form error, and the form can be retried', () async {
    final submit = controller.submit(_input());
    employees.createFails(const ApiClientException.network('offline'));
    await submit;

    expect(controller.formFailure?.kind, ApiFailureKind.network);
    expect(controller.submitting, isFalse);

    final retry = controller.submit(_input());
    expect(controller.formFailure, isNull, reason: 'cleared on retry');
    employees.createSucceeds(employee(5, 'Disan', 'Ssebowa', 'SBW'));
    expect(await retry, isNotNull);
  });
}
