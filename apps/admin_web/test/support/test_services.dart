import 'package:admin_web/src/app/admin_services.dart';
import 'package:admin_web/src/auth/admin_session.dart';
import 'package:admin_web/src/auth/platform/session_store.dart';

import 'fake_assignments_api.dart';
import 'fake_auth.dart';
import 'fake_companies_api.dart';
import 'fake_dashboard.dart';
import 'fake_employees_api.dart';
import 'fake_group_apis.dart';
import 'fake_locations.dart';
import 'fake_projects.dart';
import 'fake_reports.dart';
import 'fake_schedules_api.dart';
import 'fake_time_records_api.dart';

/// [AdminServices] wired to fakes; the fakes stay reachable for assertions.
class TestServices {
  TestServices({AdminSession? session}) {
    services = AdminServices(
      companiesApi: companies,
      employeesApi: employees,
      groupsApi: groups,
      assignmentsApi: assignments,
      schedulesApi: schedules,
      groupManagementApi: groupManagement,
      groupMembersApi: groupMembers,
      timeRecordsApi: timeRecords,
      scheduleSourceApi: scheduleSource,
      locationsApi: locations,
      reportsApi: reports,
      dashboardApi: dashboard,
      projectsApi: projects,
      session: session ??
          AdminSession.signedIn(
            auth: FakeAuthApi(),
            me: FakeMeApi(),
            companies: AllCompaniesApi(),
            store: MemorySessionStore(),
            account: testAccount,
          ),
      locationMaps: maps,
    );
  }

  final companies = FakeCompaniesApi();
  final employees = FakeEmployeesApi();
  final groups = FakeGroupsApi();
  final assignments = FakeEmployeeAssignmentsApi();
  final schedules = FakeSchedulesApi();
  final groupManagement = FakeGroupManagementApi();
  final groupMembers = FakeGroupMembersApi();
  final timeRecords = FakeTimeRecordsApi();
  final scheduleSource = FakeScheduleSourceApi();
  final locations = FakeLocationsApi();
  final reports = FakeReportsApi();
  final dashboard = FakeDashboardApi();
  final projects = FakeProjectsApi();
  late final maps = fakeLocationMaps();
  late final AdminServices services;
}
