import 'package:jitan_models/jitan_models.dart';

import '../activities/trip_kilometres.dart';
import '../companies/company_repository.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import '../time_records/my_day_service.dart';
import '../time_records/time_record_service.dart';
import '../time_records/week_plans.dart';
import '../time_registration/workplace_clock.dart';

/// The monthly hours report (Figma `1467:2`, D24): calculated when opened,
/// never stored, from the same days as Time records. It holds only what
/// Jitan can calculate; overtime and absence have no rule or data yet.
class ReportService {
  ReportService({
    required this._days,
    required this._plans,
    required this._employees,
    required this._companies,
    required this._clock,
    this._kilometres,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimeRecordService _days;
  final WeekPlans _plans;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final WorkplaceClock _clock;

  /// `null` on a database without the proposed tables.
  final TripKilometres? _kilometres;
  final DateTime Function() _now;

  static final _month = RegExp(r'^(\d{4})-(0[1-9]|1[0-2])$');

  /// [month] as `yyyy-MM`: the text, and its first and last day. 400 for a
  /// missing or malformed month.
  static ({String text, DateTime first, DateTime last}) monthOf(String? month) {
    final match = _month.firstMatch(month ?? '');
    if (match == null) throw const ApiException.validation('month', 'Give the month as yyyy-MM, e.g. 2026-10.');
    final year = int.parse(match.group(1)!), number = int.parse(match.group(2)!);
    return (text: '${match.group(1)}-${match.group(2)}', first: DateTime.utc(year, number), last: DateTime.utc(year, number + 1, 0));
  }

  static const _toReview = {
    TimeRecordStatus.missingStart,
    TimeRecordStatus.missingFinish,
    TimeRecordStatus.pendingReview,
    TimeRecordStatus.noRegistration,
  };

  /// [month] (`yyyy-MM`) for the employees of [companyId], or of every
  /// company for which [mayView] is true. An employee in several companies
  /// shows with all their hours: registrations have no company yet (GAP-03).
  ///
  /// 400 for a missing or malformed month; 404 for an unknown company.
  Future<HoursReport> hours({
    required String? month,
    required Future<bool> Function(int companyId) mayView,
    int? companyId,
  }) async {
    final match = _month.firstMatch(month ?? '');
    if (match == null) throw const ApiException.validation('month', 'Give the month as yyyy-MM, e.g. 2026-10.');
    final year = int.parse(match.group(1)!), number = int.parse(match.group(2)!);
    final first = DateTime.utc(year, number);
    final last = DateTime.utc(year, number + 1, 0);

    final List<int> companyIds;
    if (companyId != null) {
      if (!await _companies.exists(companyId)) throw ApiException.notFound('Company $companyId does not exist.');
      companyIds = [companyId];
    } else {
      companyIds = [
        for (final company in await _companies.listCompanies())
          if (await mayView(company.id)) company.id,
      ];
    }

    final employees = await _employees.listForCompanies(companyIds);
    final days = await _days.daysOf(employees, first, last);
    final plans = await _plans.of([for (final e in employees) e.id]);
    final trips = await _kilometres?.ofUsers(
      [for (final e in employees) e.id],
      _clock.utcOf(DateTime(year, number)),
      _clock.utcOf(DateTime(year, number + 1)),
    );
    final local = _clock.wallClockOf(_now().toUtc());
    final today = DateTime.utc(local.year, local.month, local.day);
    final end = last.isBefore(today) ? last : today;

    final rows = <HoursReportEmployee>[];
    for (final employee in employees) {
      final week = plans[employee.id] ?? const {};
      final byDate = {for (final d in days) if (d.employeeId == employee.id) d.date: d};
      var planned = 0, registered = 0, travel = 0, toReview = 0;
      final reportDays = <HoursReportDay>[];
      for (var date = first; !date.isAfter(end); date = DateTime.utc(date.year, date.month, date.day + 1)) {
        final plan = week[date.weekday];
        final day = byDate[date];
        if (day?.status != TimeRecordStatus.nonWork) planned += WeekPlans.plannedMinutes(plan) ?? 0;
        if (day == null) continue;
        final minutes = MyDayService.registeredMinutes(day, plan?.breakMinutes ?? 0);
        registered += minutes ?? 0;
        travel += day.transportMinutes;
        if (_toReview.contains(day.status)) toReview++;
        reportDays.add(
          HoursReportDay(
            date: date,
            status: day.status,
            start: day.start?.roundedLocal ?? day.start?.actualLocal,
            finish: day.finish?.roundedLocal ?? day.finish?.actualLocal,
            registeredMinutes: minutes,
            awayMinutes: day.awayMinutes,
          ),
        );
      }
      if (planned == 0 && reportDays.isEmpty) continue;
      final travelled = trips?[employee.id];
      rows.add(
        HoursReportEmployee(
          employeeId: employee.id,
          firstName: employee.firstName,
          lastName: employee.lastName,
          code: employee.code,
          plannedMinutes: planned,
          registeredMinutes: registered,
          daysToReview: toReview,
          days: reportDays.reversed.toList(),
          trips: travelled?.trips ?? 0,
          distanceMetres: travelled?.metres ?? 0,
          tripsWithoutDistance: travelled?.unknown ?? 0,
          travelMinutes: travel,
        ),
      );
    }
    return HoursReport(month: '${match.group(1)}-${match.group(2)}', employees: rows);
  }
}
