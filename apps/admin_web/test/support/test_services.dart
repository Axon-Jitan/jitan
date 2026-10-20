import 'package:admin_web/src/app/admin_services.dart';

import 'fake_assignments_api.dart';
import 'fake_companies_api.dart';
import 'fake_employees_api.dart';
import 'fake_schedules_api.dart';

/// [AdminServices] wired to fakes; the fakes stay reachable for assertions.
class TestServices {
  TestServices({bool devTools = false}) {
    services = AdminServices(
      companiesApi: companies,
      employeesApi: employees,
      groupsApi: groups,
      assignmentsApi: assignments,
      schedulesApi: schedules,
      devTools: devTools,
    );
  }

  final companies = FakeCompaniesApi();
  final employees = FakeEmployeesApi();
  final groups = FakeGroupsApi();
  final assignments = FakeEmployeeAssignmentsApi();
  final schedules = FakeSchedulesApi();
  late final AdminServices services;
}
