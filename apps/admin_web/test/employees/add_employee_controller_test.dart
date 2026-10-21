import 'package:admin_web/src/employees/add_employee_controller.dart';
import 'package:admin_web/src/l10n/admin_text_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_employees_api.dart';
import '../support/fake_schedules_api.dart';

NewEmployeeInput _input({String first = 'Disan', String code = 'SBW', String email = ''}) =>
    (firstName: first, lastName: 'Ssebowa', code: code, phone: '', email: email);

ApiClientException _server(int status, String code, {String? field}) =>
    ApiClientException.server(status, ApiError(code: code, message: 'x', field: field));

final _white = groupSchedule(3, 'White collar', work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'), breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30));
final _drivers = groupSchedule(4, 'Drivers', work: workDays([1, 2, 3, 4, 5], '06:00', '14:30'), breakDays: breaks([1, 2, 3, 4, 5], '10:00', 30));
final _night = groupSchedule(5, 'Night', status: GroupScheduleStatus.noSchedule);

void main() {
  late FakeEmployeesApi employees;
  late FakeGroupsApi groups;
  late FakeCompaniesApi companies;
  late FakeSchedulesApi schedules;
  late AddEmployeeController controller;

  setUp(() {
    employees = FakeEmployeesApi();
    groups = FakeGroupsApi();
    companies = FakeCompaniesApi();
    schedules = FakeSchedulesApi();
    controller = AddEmployeeController(
      employeesApi: employees,
      groupsApi: groups,
      companiesApi: companies,
      schedulesApi: schedules,
      companyId: 7,
    );
  });
  tearDown(() => controller.dispose());

  /// Step 1 done, step 2's choices loaded.
  Future<void> toStep2() async {
    controller.next(_input());
    await Future<void>.delayed(Duration.zero);
    companies.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
    await Future<void>.delayed(Duration.zero);
    groups.succeed(const [GroupSummary(id: 3, name: 'White collar'), GroupSummary(id: 4, name: 'Drivers'), GroupSummary(id: 5, name: 'Night')]);
    await Future<void>.delayed(Duration.zero);
    schedules.succeedList([_white, _drivers, _night]);
    await Future<void>.delayed(Duration.zero);
  }

  test('step 1: required fields and the email are checked before step 2', () {
    controller.next(_input(first: ' ', email: 'disan.example.com'));

    expect(controller.step, AddEmployeeStep.information);
    expect(controller.fieldErrors, {
      CreateEmployeeRequest.fieldFirstName: AdminTextKeys.employeeFieldErrorRequired,
      CreateEmployeeRequest.fieldEmail: AdminTextKeys.employeeFieldErrorEmail,
    });
    expect(companies.calls, isEmpty, reason: 'nothing is loaded before step 2');
  });

  test('step 2: the current company is always chosen; Work schedule offers only the chosen groups\' hours', () async {
    await toStep2();
    expect(controller.step, AddEmployeeStep.assignments);
    expect(controller.companyIds, [7]);

    controller.setCompanies([8]);
    expect(controller.companyIds, [7, 8], reason: 'Almeco stays');

    controller.setGroups([3]);
    expect([for (final s in controller.scheduleChoices) s.group.name], ['White collar']);
    expect(controller.scheduleGroupId, 3, reason: 'one choice: chosen for HR');

    controller.setGroups([3, 4, 5]);
    expect([for (final s in controller.scheduleChoices) s.group.name], ['White collar', 'Drivers'], reason: 'Night has no hours');
    expect(controller.scheduleGroupId, isNull, reason: 'several: HR chooses');
    controller.setScheduleGroup(4);
    expect(controller.scheduleGroupId, 4);
  });

  test('creating sends everything in one request, then asks for the onboarding QR', () async {
    await toStep2();
    controller
      ..setCompanies([8])
      ..setGroups([3, 4])
      ..setScheduleGroup(4);

    final creating = controller.create();
    expect(controller.submitting, isTrue);
    final (companyId, request) = employees.creates.single;
    expect(companyId, 7);
    expect(request.companyIds, [7, 8]);
    expect(request.groupIds, [3, 4]);
    expect(request.scheduleGroupId, 4);
    expect(request.email, isNull, reason: 'blank email is not sent');

    employees.createSucceeds(employee(20, 'Disan', 'Ssebowa', 'SBW'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.step, AddEmployeeStep.activation);
    expect(employees.qrRequests, [(7, 20, TemporaryQrPurpose.onboarding)]);
    employees.qrSucceeds('qr-value', expiresAt: DateTime.utc(2026, 10, 21, 12, 10));
    await creating;
    expect(controller.qr!.qrCode, 'qr-value');
  });

  test('a taken code takes HR back to step 1, under the code', () async {
    await toStep2();
    final creating = controller.create();
    employees.createFails(_server(409, ApiErrorCode.duplicateEmployeeCode, field: 'code'));
    await creating;

    expect(controller.step, AddEmployeeStep.information);
    expect(controller.fieldErrors, {CreateEmployeeRequest.fieldCode: AdminTextKeys.employeeFieldErrorDuplicateCode});
  });

  test('a group no longer available stays on step 2, under the groups', () async {
    await toStep2();
    controller.setGroups([3]);
    final creating = controller.create();
    employees.createFails(_server(400, ApiErrorCode.validationFailed, field: CreateEmployeeRequest.fieldGroupIds));
    await creating;

    expect(controller.step, AddEmployeeStep.assignments);
    expect(controller.fieldErrors, {CreateEmployeeRequest.fieldGroupIds: AdminTextKeys.employeeFieldErrorUnavailable});
  });
}
