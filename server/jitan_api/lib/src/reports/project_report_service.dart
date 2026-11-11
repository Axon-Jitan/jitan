import 'package:jitan_models/jitan_models.dart';

import '../activities/activity_repository.dart';
import '../activities/trip_kilometres.dart';
import '../companies/company_repository.dart';
import '../database/sql_executor.dart';
import '../employees/employee_repository.dart';
import '../locations/location_repository.dart';
import '../projects/project_repository.dart';
import '../projects/project_service.dart';
import '../time_records/time_record_service.dart';
import '../time_records/week_plans.dart';
import '../time_registration/workplace_clock.dart';
import 'project_report_days.dart';
import 'report_period.dart';

/// The project report (Figma `1515:2`, a project `1515:190`, D24):
/// calculated when opened, never stored. A project has no company (D44), so
/// it holds the employees of every company where the viewer may see reports,
/// each company checked on its own (ENGINEERING_RULES §28a.5).
class ProjectReportService {
  ProjectReportService({
    required this._days,
    required this._plans,
    required this._employees,
    required this._companies,
    required this._activities,
    required this._projects,
    required this._locations,
    required this._kilometres,
    required this._executor,
    required this._clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimeRecordService _days;
  final WeekPlans _plans;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final ActivityRepository _activities;
  final ProjectRepository _projects;
  final LocationRepository _locations;
  final TripKilometres _kilometres;
  final SqlExecutor _executor;
  final WorkplaceClock _clock;
  final DateTime Function() _now;

  /// The period [from]–[to] (`yyyy-MM-dd`, both included). 400 for a
  /// missing, malformed, reversed or too long period.
  Future<ProjectReport> projects({
    required String? from,
    required String? to,
    required Future<bool> Function(int companyId) mayView,
  }) async {
    final (:first, :last) = ReportPeriod.parse(from, to);
    final companyIds = [
      for (final company in await _companies.listCompanies())
        if (await mayView(company.id)) company.id,
    ];
    final employees = await _employees.listForCompanies(companyIds);
    if (employees.isEmpty) return ProjectReport(from: first, to: last, projects: const []);
    final ids = [for (final e in employees) e.id];

    final activities = await _activities.ofUsers(
      _executor,
      ids,
      _clock.utcOf(DateTime(first.year, first.month, first.day)),
      _clock.utcOf(DateTime(last.year, last.month, last.day + 1)),
    );
    final days = await _days.daysOf(employees, first, last);
    final plans = await _plans.of(ids);
    final workshops = {
      for (final w in await _locations.all(_executor, withProjects: false)) ?ProjectRepository.coordinatesOf(w.point): w.name,
    };
    final projects = {
      for (final row in await _projects.list(_executor)) row.id: ProjectService.summaryOf(row, workshops),
    };
    final trips = <Trip>[
      for (final rows in activities.values) ..._tripsByDay(rows),
    ];

    return ProjectReport(
      from: first,
      to: last,
      projects: ProjectReportDays.build(
        employees: employees,
        days: days,
        activities: activities,
        plans: plans,
        projects: projects,
        metres: await _kilometres.metresOf(trips),
        clock: _clock,
        now: _now().toUtc(),
      ),
    );
  }

  /// Every trip of one employee's rows, day by day.
  List<Trip> _tripsByDay(List<ActivityRow> rows) {
    final byDate = <DateTime, List<ActivityRow>>{};
    for (final row in rows) {
      final local = _clock.wallClockOf(row.at);
      byDate.putIfAbsent(DateTime.utc(local.year, local.month, local.day), () => []).add(row);
    }
    return [
      for (final day in byDate.values) ...TripKilometres.tripsOf(day..sort((a, b) => a.at.compareTo(b.at))),
    ];
  }
}
