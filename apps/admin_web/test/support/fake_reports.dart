import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

HoursReportEmployee reportEmployee(
  int id,
  String first,
  String last,
  String code, {
  int planned = 9600,
  int registered = 9600,
  int toReview = 0,
  int trips = 0,
  int metres = 0,
  int unknownTrips = 0,
  int travel = 0,
  List<HoursReportDay> days = const [],
}) => HoursReportEmployee(
  employeeId: id,
  firstName: first,
  lastName: last,
  code: code,
  plannedMinutes: planned,
  registeredMinutes: registered,
  daysToReview: toReview,
  trips: trips,
  distanceMetres: metres,
  tripsWithoutDistance: unknownTrips,
  travelMinutes: travel,
  days: days,
);

/// One project's month, with [employees] on it.
ProjectReportProject reportProject(
  int id,
  String sapNumber,
  String name, {
  String? place = 'Mouscron',
  bool client = true,
  int worked = 600,
  int travel = 0,
  int trips = 0,
  int metres = 0,
  int unknownTrips = 0,
  List<ProjectReportEmployee> employees = const [],
}) => ProjectReportProject(
  project: ProjectSummary(id: id, sapNumber: sapNumber, name: name, isClientSite: client, isActive: true, placeName: place),
  workedMinutes: worked,
  travelMinutes: travel,
  trips: trips,
  distanceMetres: metres,
  tripsWithoutDistance: unknownTrips,
  employees: employees,
);

/// Stand-in for [ReportsApi]: the same employees and projects for every
/// month, except [emptyMonths].
class FakeReportsApi implements ReportsApi {
  List<HoursReportEmployee> employees = [];
  List<ProjectReportProject> projectRows = [];
  final projectCalls = <String>[];
  Set<String> emptyMonths = {};
  ApiClientException? fail;
  final calls = <(String, int?)>[];

  @override
  Future<HoursReport> hours(String month, {int? companyId}) async {
    calls.add((month, companyId));
    if (fail case final failure?) throw failure;
    return HoursReport(month: month, employees: emptyMonths.contains(month) ? const [] : employees);
  }

  @override
  Future<ProjectReport> projects(String month) async {
    projectCalls.add(month);
    if (fail case final failure?) throw failure;
    return ProjectReport(month: month, projects: emptyMonths.contains(month) ? const [] : projectRows);
  }
}
