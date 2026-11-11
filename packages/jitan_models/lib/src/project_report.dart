import 'json_reading.dart';
import 'project.dart';

/// One employee's month on one project.
class ProjectReportEmployee {
  const ProjectReportEmployee({
    required this.employeeId,
    required this.code,
    required this.days,
    required this.workedMinutes,
    required this.travelMinutes,
    required this.trips,
    this.firstName,
    this.lastName,
  });

  factory ProjectReportEmployee.fromJson(Map<String, Object?> json) => ProjectReportEmployee(
    employeeId: json.readInt('employeeId'),
    firstName: json.readOptionalString('firstName'),
    lastName: json.readOptionalString('lastName'),
    code: json.readString('code'),
    days: json.readInt('days'),
    workedMinutes: json.readInt('workedMinutes'),
    travelMinutes: json.readInt('travelMinutes'),
    trips: json.readInt('trips'),
  );

  final int employeeId;
  final String? firstName;
  final String? lastName;
  final String code;

  /// Days with work or a trip for the project.
  final int days;
  final int workedMinutes;

  /// Time on the way to the project (or back from it), never part of
  /// [workedMinutes] (D46).
  final int travelMinutes;
  final int trips;

  Map<String, Object?> toJson() => {
    'employeeId': employeeId,
    'firstName': firstName,
    'lastName': lastName,
    'code': code,
    'days': days,
    'workedMinutes': workedMinutes,
    'travelMinutes': travelMinutes,
    'trips': trips,
  };
}

/// One project's month (D24): who worked on it, their time, its trips and
/// their normal route.
class ProjectReportProject {
  const ProjectReportProject({
    required this.project,
    required this.workedMinutes,
    required this.travelMinutes,
    required this.trips,
    required this.distanceMetres,
    required this.tripsWithoutDistance,
    required this.employees,
  });

  factory ProjectReportProject.fromJson(Map<String, Object?> json) => ProjectReportProject(
    project: ProjectSummary.fromJson(json.readObject('project')),
    workedMinutes: json.readInt('workedMinutes'),
    travelMinutes: json.readInt('travelMinutes'),
    trips: json.readInt('trips'),
    distanceMetres: json.readInt('distanceMetres'),
    tripsWithoutDistance: json.readInt('tripsWithoutDistance'),
    employees: json.readObjectList('employees').map(ProjectReportEmployee.fromJson).toList(),
  );

  final ProjectSummary project;
  final int workedMinutes;
  final int travelMinutes;
  final int trips;
  final int distanceMetres;

  /// Trips whose place or route isn't known: [distanceMetres] leaves them out.
  final int tripsWithoutDistance;

  /// The most worked first.
  final List<ProjectReportEmployee> employees;

  Map<String, Object?> toJson() => {
    'project': project.toJson(),
    'workedMinutes': workedMinutes,
    'travelMinutes': travelMinutes,
    'trips': trips,
    'distanceMetres': distanceMetres,
    'tripsWithoutDistance': tripsWithoutDistance,
    'employees': [for (final e in employees) e.toJson()],
  };
}

/// Response body of `GET /reports/projects`: the projects worked on or
/// travelled to in a month, the most worked first.
class ProjectReport {
  const ProjectReport({required this.month, required this.projects});

  factory ProjectReport.fromJson(Map<String, Object?> json) => ProjectReport(
    month: json.readString('month'),
    projects: json.readObjectList('projects').map(ProjectReportProject.fromJson).toList(),
  );

  /// `yyyy-MM`.
  final String month;
  final List<ProjectReportProject> projects;

  Map<String, Object?> toJson() => {
    'month': month,
    'projects': [for (final p in projects) p.toJson()],
  };
}
