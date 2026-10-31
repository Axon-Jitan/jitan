import 'package:jitan_models/jitan_models.dart';

import '../companies/company_repository.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import '../locations/location_service.dart';
import '../time_records/my_day_service.dart';
import '../time_records/time_record_service.dart';
import '../time_records/week_plans.dart';
import '../time_registration/rounding/attendance_calculator.dart';
import '../time_registration/workplace_clock.dart';

/// The HR Dashboard (Figma `1470:2`, period picker `1475:16`): calculated when
/// opened, from the same days as Time records and Reports, so the numbers
/// agree. Only what Jitan can calculate; terminals, "away" and hours per
/// company have no data yet.
class DashboardService {
  DashboardService({
    required this._days,
    required this._plans,
    required this._employees,
    required this._companies,
    required this._locations,
    required this._clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimeRecordService _days;
  final WeekPlans _plans;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final LocationService _locations;
  final WorkplaceClock _clock;
  final DateTime Function() _now;

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// A period up to this long gets a bar per day (a month and a bit).
  static const _maxDailyDays = 35;

  /// Up to this long, a bar per week; longer, a bar per month.
  static const _maxWeeklyDays = 184;

  /// How far back a correction still waits for HR.
  static const _correctionsDays = 62;

  static const _toReview = {
    TimeRecordStatus.missingStart,
    TimeRecordStatus.missingFinish,
    TimeRecordStatus.pendingReview,
    TimeRecordStatus.noRegistration,
  };

  /// 400 for a missing, malformed, reversed or too long period.
  Future<Dashboard> dashboard({
    required String? from,
    required String? to,
    required Future<bool> Function(int companyId) mayView,
  }) async {
    final first = _parseDate(from, 'from');
    final last = _parseDate(to, 'to');
    if (last.isBefore(first)) throw const ApiException.validation('to', 'The period ends before it starts.');
    final length = last.difference(first).inDays + 1;
    if (length > Dashboard.maxDays) {
      throw const ApiException.validation('to', 'A period can be at most ${Dashboard.maxDays} days.');
    }

    final companies = [
      for (final company in await _companies.listCompanies())
        if (company.isActive && await mayView(company.id)) company,
    ];
    // Everyone, so past hours match Reports; today and the totals only count
    // who is still active.
    final employees = await _employees.listForCompanies([for (final c in companies) c.id]);
    final active = [
      for (final e in employees)
        if (e.isActive) e,
    ];
    final plans = await _plans.of([for (final e in employees) e.id]);

    final local = _clock.wallClockOf(_now().toUtc());
    final today = DateTime.utc(local.year, local.month, local.day);
    final waitingFrom = today.subtract(const Duration(days: _correctionsDays - 1));
    final loadFrom = first.isBefore(waitingFrom) ? first : waitingFrom;
    final loadTo = last.isAfter(today) ? last : today;
    final days = await _days.daysOf(employees, loadFrom, loadTo);
    final byEmployeeDate = {for (final d in days) (d.employeeId, d.date): d};

    // Today, and corrections, whatever the period.
    var working = 0, finished = 0, notStarted = 0, corrections = 0;
    for (final employee in active) {
      final day = byEmployeeDate[(employee.id, today)];
      final scheduled = WeekPlans.plannedMinutes(plans[employee.id]?[today.weekday]) != null;
      if (day == null) {
        if (scheduled) notStarted++;
      } else if (day.finish != null) {
        finished++;
      } else if (day.start != null || day.pending.isNotEmpty) {
        working++;
      } else if (scheduled && day.status != TimeRecordStatus.nonWork) {
        notStarted++;
      }
    }
    for (final day in days) {
      if (!day.date.isBefore(waitingFrom)) corrections += day.pending.length;
    }

    // The period, up to today.
    final end = last.isBefore(today) ? last : today;
    final buckets = _buckets(first, last, length);
    final registeredIn = List.filled(buckets.length, 0);
    final plannedIn = List.filled(buckets.length, 0);
    var onTime = 0, late = 0, leftEarly = 0, toReview = 0;
    for (final employee in employees) {
      final week = plans[employee.id] ?? const <int, DayPlan>{};
      var bucket = 0;
      for (var date = first; !date.isAfter(end); date = DateTime.utc(date.year, date.month, date.day + 1)) {
        while (date.isAfter(buckets[bucket].to)) {
          bucket++;
        }
        final plan = week[date.weekday];
        final day = byEmployeeDate[(employee.id, date)];
        if (day?.status != TimeRecordStatus.nonWork) plannedIn[bucket] += WeekPlans.plannedMinutes(plan) ?? 0;
        if (day == null) continue;
        registeredIn[bucket] += MyDayService.registeredMinutes(day, plan?.breakMinutes ?? 0) ?? 0;
        if (_toReview.contains(day.status)) {
          toReview++;
        } else if (day.status == TimeRecordStatus.complete || day.status == TimeRecordStatus.corrected) {
          switch (_attendanceOf(day, plan)) {
            case null:
              break;
            case _Attendance.onTime:
              onTime++;
            case _Attendance.late:
              late++;
            case _Attendance.leftEarly:
              leftEarly++;
          }
        }
      }
    }

    int sum(List<int> values) => values.fold(0, (total, v) => total + v);
    return Dashboard(
      working: working,
      finished: finished,
      notStarted: notStarted,
      companies: [
        for (final company in companies)
          DashboardCompany(id: company.id, name: company.name, employees: company.employeeCount),
      ],
      employees: active.length,
      employeesSetUp: active.where((e) => e.isActivated).length,
      locations: (await _locations.recognised()).length,
      registeredMinutes: sum(registeredIn),
      plannedMinutes: sum(plannedIn),
      bucketSize: _sizeOf(length),
      buckets: [
        for (final (i, bucket) in buckets.indexed)
          DashboardHoursBucket(
            from: bucket.from,
            to: bucket.to,
            registeredMinutes: registeredIn[i],
            plannedMinutes: plannedIn[i],
          ),
      ],
      onTime: onTime,
      late: late,
      leftEarly: leftEarly,
      toReview: toReview,
      correctionsWaiting: corrections,
    );
  }

  /// One finished day against its schedule (D11b); a day both late and left
  /// early counts once, as late. `null` without a schedule to compare with.
  _Attendance? _attendanceOf(TimeRecordDay day, DayPlan? plan) {
    final start = _at(day.date, plan?.start), finish = _at(day.date, plan?.finish);
    final startTime = day.start?.actual, finishTime = day.finish?.actual;
    if (plan == null || start == null || finish == null || startTime == null || finishTime == null) return null;
    final arrival = AttendanceCalculator.arrival(
      actual: _clock.wallClockOf(startTime),
      scheduledStart: start,
      tolerance: Duration(minutes: plan.startMargin),
    );
    if (arrival == ArrivalStatus.late) return _Attendance.late;
    final departure = AttendanceCalculator.departure(
      actual: _clock.wallClockOf(finishTime),
      scheduledFinish: finish,
      tolerance: Duration(minutes: plan.finishMargin),
    );
    return departure == DepartureStatus.early ? _Attendance.leftEarly : _Attendance.onTime;
  }

  static DateTime? _at(DateTime date, String? hhmm) {
    final match = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    if (match == null) return null;
    return DateTime.utc(date.year, date.month, date.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static DashboardBucketSize _sizeOf(int days) => days <= _maxDailyDays
      ? DashboardBucketSize.day
      : days <= _maxWeeklyDays
      ? DashboardBucketSize.week
      : DashboardBucketSize.month;

  static List<({DateTime from, DateTime to})> _buckets(DateTime first, DateTime last, int days) {
    DateTime endOf(DateTime date) => switch (_sizeOf(days)) {
      DashboardBucketSize.day => date,
      DashboardBucketSize.week => DateTime.utc(date.year, date.month, date.day + 7 - date.weekday),
      DashboardBucketSize.month => DateTime.utc(date.year, date.month + 1, 0),
    };
    final buckets = <({DateTime from, DateTime to})>[];
    var from = first;
    while (!from.isAfter(last)) {
      final end = endOf(from);
      final to = end.isAfter(last) ? last : end;
      buckets.add((from: from, to: to));
      from = DateTime.utc(to.year, to.month, to.day + 1);
    }
    return buckets;
  }

  static DateTime _parseDate(String? value, String field) {
    if (value == null || !_date.hasMatch(value)) {
      throw ApiException.validation(field, 'Give "$field" as a date, e.g. 2026-10-22.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw ApiException.validation(field, 'Give "$field" as a date, e.g. 2026-10-22.');
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}

enum _Attendance { onTime, late, leftEarly }
