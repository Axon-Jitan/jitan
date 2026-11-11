import 'package:jitan_models/jitan_models.dart';

import '../activities/activity_minutes.dart';
import '../activities/activity_repository.dart';
import '../activities/trip_kilometres.dart';
import '../time_records/my_day_service.dart';
import '../time_records/week_plans.dart';
import '../time_registration/workplace_clock.dart';

/// The project report's numbers (D24, D44, D46): pure, no database or clock
/// of its own.
///
/// - **Worked** on a project: each activity row whose `addressID` is the
///   project, until the next activity or the day's finish, inside the day's
///   rounded start and finish, without time away or else the break, so a day
///   on one project adds up to the hours report's Worked.
/// - **Travel**: each trip (transports in a row) belongs to the project it
///   arrives at, else to the project it leaves from; its time runs until the
///   next activity or the finish, as in the hours report, and is never part
///   of Worked. Its distance is the normal route (D23).
/// - Only days the hours report counts: finished, with nothing waiting for
///   HR. Days to review stay out until they are fixed.
abstract final class ProjectReportDays {
  static List<ProjectReportProject> build({
    required List<EmployeeSummary> employees,
    required List<TimeRecordDay> days,
    required Map<int, List<ActivityRow>> activities,
    required Map<int, Map<int, DayPlan>> plans,
    required Map<int, ProjectSummary> projects,
    required Map<Trip, int?> metres,
    required WorkplaceClock clock,
  }) {
    final totals = <int, Map<int, _Totals>>{};
    _Totals of(int projectId, int employeeId) =>
        totals.putIfAbsent(projectId, () => {}).putIfAbsent(employeeId, _Totals.new);
    final dayOf = {for (final d in days) (d.employeeId, d.date): d};

    for (final employee in employees) {
      final byDate = <DateTime, List<ActivityRow>>{};
      for (final row in activities[employee.id] ?? const <ActivityRow>[]) {
        final local = clock.wallClockOf(row.at);
        byDate.putIfAbsent(DateTime.utc(local.year, local.month, local.day), () => []).add(row);
      }
      for (final MapEntry(key: date, value: rows) in byDate.entries) {
        final day = dayOf[(employee.id, date)];
        final plan = plans[employee.id]?[date.weekday];
        if (day == null || MyDayService.registeredMinutes(day, plan?.breakMinutes ?? 0) == null) continue;
        final start = day.start!.rounded!, finish = day.finish!.rounded!;
        final left = day.awayMinutes > 0 ? ActivityMinutes.timeAway(day) : _breakOf(plan);
        rows.sort((a, b) => a.at.compareTo(b.at));
        bool isTransport(int i) => rows[i].typeName == ActivityRepository.transportType;

        for (final (i, row) in rows.indexed) {
          final projectId = row.addressId;
          if (isTransport(i) || projectId == null || !projects.containsKey(projectId)) continue;
          final from = _later(row.at, start);
          final next = i + 1 < rows.length ? rows[i + 1].at : finish;
          final to = next.isBefore(finish) ? next : finish;
          if (!to.isAfter(from)) continue;
          final minutes = ActivityMinutes.between(clock, from, to, left);
          if (minutes == 0) continue;
          of(projectId, employee.id)
            ..worked += minutes
            ..days.add(date);
        }

        final trips = TripKilometres.tripsOf(rows);
        var trip = 0;
        for (var i = 0; i < rows.length; i++) {
          if (!isTransport(i) || (i > 0 && isTransport(i - 1))) continue;
          var minutes = 0;
          for (var k = i; k < rows.length && isTransport(k); k++) {
            final end = k + 1 < rows.length ? rows[k + 1].at : day.finish!.actual;
            if (end.isAfter(rows[k].at)) minutes += end.difference(rows[k].at).inMinutes;
          }
          final route = trips[trip++];
          final projectId = projects.containsKey(route.to) ? route.to : (projects.containsKey(route.from) ? route.from : null);
          if (projectId == null) continue;
          final distance = metres[route];
          of(projectId, employee.id)
            ..travel += minutes
            ..trips += 1
            ..metres += distance ?? 0
            ..unknown += distance == null ? 1 : 0
            ..days.add(date);
        }
      }
    }

    final people = {for (final e in employees) e.id: e};
    final report = [
      for (final MapEntry(key: projectId, value: byEmployee) in totals.entries)
        ProjectReportProject(
          project: projects[projectId]!,
          workedMinutes: byEmployee.values.fold(0, (sum, t) => sum + t.worked),
          travelMinutes: byEmployee.values.fold(0, (sum, t) => sum + t.travel),
          trips: byEmployee.values.fold(0, (sum, t) => sum + t.trips),
          distanceMetres: byEmployee.values.fold(0, (sum, t) => sum + t.metres),
          tripsWithoutDistance: byEmployee.values.fold(0, (sum, t) => sum + t.unknown),
          employees: [
            for (final MapEntry(key: employeeId, value: t) in byEmployee.entries)
              ProjectReportEmployee(
                employeeId: employeeId,
                firstName: people[employeeId]!.firstName,
                lastName: people[employeeId]!.lastName,
                code: people[employeeId]!.code,
                days: t.days.length,
                workedMinutes: t.worked,
                travelMinutes: t.travel,
                trips: t.trips,
              ),
          ]..sort((a, b) => b.workedMinutes != a.workedMinutes ? b.workedMinutes.compareTo(a.workedMinutes) : a.code.compareTo(b.code)),
        ),
    ];
    report.sort(
      (a, b) => b.workedMinutes != a.workedMinutes
          ? b.workedMinutes.compareTo(a.workedMinutes)
          : a.project.fullName.compareTo(b.project.fullName),
    );
    return report;
  }

  /// The schedule's break, as a stretch of the day; none without one.
  static List<MinuteSpan> _breakOf(DayPlan? plan) {
    final from = plan?.breakStart, to = plan?.breakFinish;
    if (from == null || to == null) return const [];
    return [(ActivityMinutes.minuteOf(from), ActivityMinutes.minuteOf(to))];
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
}

/// One employee's numbers on one project, while adding up.
class _Totals {
  final days = <DateTime>{};
  var worked = 0;
  var travel = 0;
  var trips = 0;
  var metres = 0;
  var unknown = 0;
}
