import 'package:jitan_models/jitan_models.dart';

import '../companies/company_repository.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import '../schedules/schedule_names.dart';
import '../schedules/schedule_repository.dart';
import '../time_registration/registration_rounding.dart';
import '../time_registration/rounding/rounding_calculator.dart';
import '../time_registration/rounding/rounding_policy.dart';
import '../time_registration/workplace_clock.dart';
import 'time_record_days.dart';
import 'time_record_repository.dart';

/// HR/Admin Time records (phase 3, slice 2; Figma `160:2`): the employees'
/// working days in a period, each with its actual and rounded start and
/// finish and a calculated status.
class TimeRecordService {
  TimeRecordService({
    required this._records,
    required this._employees,
    required this._companies,
    required this._clock,
    required this._schedules,
    required this._rounding,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimeRecordRepository _records;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final WorkplaceClock _clock;
  final ScheduleRepository _schedules;
  final RegistrationRounding _rounding;
  final DateTime Function() _now;

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Days from [from] to [to] (workplace-local dates `yyyy-MM-dd`, both
  /// inclusive, at most [TimeRecordList.maxPeriodDays]) of the employees of
  /// [companyId], or of every company for which [mayView] is true, filtered
  /// by name or code with [search].
  ///
  /// 400 for a missing or malformed date, a reversed or too long period, or
  /// a search longer than [EmployeeService.maxSearchLength]-like limit; 404
  /// for an unknown company.
  Future<TimeRecordList> records({
    int? companyId,
    String? search,
    required String? from,
    required String? to,
    required Future<bool> Function(int companyId) mayView,
  }) async {
    final first = _parseDate(from, 'from');
    final last = _parseDate(to, 'to');
    if (last.isBefore(first)) throw const ApiException.validation('to', 'The period ends before it starts.');
    if (last.difference(first).inDays + 1 > TimeRecordList.maxPeriodDays) {
      throw const ApiException.validation('to', 'A period can be at most ${TimeRecordList.maxPeriodDays} days.');
    }
    final term = search?.trim() ?? '';
    if (term.length > 100) throw const ApiException.badRequest('Search text must be at most 100 characters.');

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

    final employees = await _employees.listForCompanies(companyIds, nameOrCodeContains: term.isEmpty ? null : term);
    return TimeRecordList(days: await daysOf(employees, first, last));
  }

  /// The days of [employees] from [first] to [last] (local dates), with each
  /// pending correction's rounded time.
  Future<List<TimeRecordDay>> daysOf(List<EmployeeSummary> employees, DateTime first, DateTime last) async {
    final ids = [for (final e in employees) e.id];
    final rows = await _records.registrationsOf(ids, _clock.utcOf(first), _clock.utcOf(last.add(const Duration(days: 1))));
    final local = _clock.wallClockOf(_now().toUtc());
    final days = TimeRecordDays.build(
      rows: rows,
      employees: {for (final e in employees) e.id: e},
      clock: _clock,
      today: DateTime.utc(local.year, local.month, local.day),
      scheduledWeekdays: await _workWeekdays(ids),
      firstRegistrations: await _records.firstRegistrations(ids),
      from: first,
      to: last,
    );
    return [for (final day in days) day.pending.isEmpty ? day : await _withPreview(day)];
  }

  /// ISO weekdays on which each employee has a "Work – start" schedule.
  Future<Map<int, Set<int>>> _workWeekdays(List<int> userIds) async {
    if (userIds.isEmpty) return const {};
    final dayNames = {for (final d in await _schedules.listDays()) d.id: DayNames.weekdayOf(d.name)};
    final weekdays = <int, Set<int>>{};
    for (final row in await _schedules.schedulesOf(userIds)) {
      final weekday = dayNames[row.dayId];
      if (row.typeName == ScheduleTypeNames.workStart && weekday != null) {
        weekdays.putIfAbsent(row.userId, () => {}).add(weekday);
      }
    }
    return weekdays;
  }

  /// [day] with what each pending correction would count as after rounding.
  Future<TimeRecordDay> _withPreview(TimeRecordDay day) async {
    final policy = await _rounding.policyOn(day.employeeId, day.date.weekday);
    String preview(TimeRecordPending p) {
      final rounded = RoundingCalculator.round(
        actual: _clock.wallClockOf(p.requested),
        boundary: p.boundary == RegistrationBoundary.start ? RoundingBoundary.start : RoundingBoundary.finish,
        policy: policy,
      ).registered;
      return '${rounded.hour.toString().padLeft(2, '0')}:${rounded.minute.toString().padLeft(2, '0')}';
    }

    return TimeRecordDay(
      employeeId: day.employeeId,
      firstName: day.firstName,
      lastName: day.lastName,
      employeeCode: day.employeeCode,
      date: day.date,
      status: day.status,
      start: day.start,
      finish: day.finish,
      pending: [
        for (final p in day.pending)
          TimeRecordPending(
            id: p.id,
            boundary: p.boundary,
            requested: p.requested,
            requestedLocal: p.requestedLocal,
            reason: p.reason,
            roundedLocal: preview(p),
          ),
      ],
      events: day.events,
      nonWorkReason: day.nonWorkReason,
    );
  }

  static DateTime _parseDate(String? value, String field) {
    if (value == null || !_date.hasMatch(value)) {
      throw ApiException.validation(field, 'Give "$field" as a date, e.g. 2026-10-22.');
    }
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
