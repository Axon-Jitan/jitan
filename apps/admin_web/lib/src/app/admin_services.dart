import 'package:jitan_api_client/jitan_api_client.dart';

import '../auth/admin_session.dart';
import '../locations/location_map.dart';

/// The API clients and build options the HR/Admin pages need, passed down
/// from `main` in one value.
class AdminServices {
  const AdminServices({
    required this.companiesApi,
    required this.employeesApi,
    required this.groupsApi,
    required this.assignmentsApi,
    required this.schedulesApi,
    required this.groupManagementApi,
    required this.groupMembersApi,
    required this.timeRecordsApi,
    required this.scheduleSourceApi,
    required this.locationsApi,
    required this.reportsApi,
    required this.session,
    this.locationMaps,
  });

  final CompaniesApi companiesApi;
  final EmployeesApi employeesApi;
  final GroupsApi groupsApi;
  final EmployeeAssignmentsApi assignmentsApi;
  final SchedulesApi schedulesApi;
  final GroupManagementApi groupManagementApi;
  final GroupMembersApi groupMembersApi;
  final TimeRecordsApi timeRecordsApi;

  /// "Schedules come from" for employees in several groups.
  final ScheduleSourceApi scheduleSourceApi;
  final LocationsApi locationsApi;
  final ReportsApi reportsApi;
  final AdminSession session;

  /// The Locations map; `null` when the build has no Mapbox token.
  final LocationMaps? locationMaps;
}
