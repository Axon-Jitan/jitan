import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';
import '../schedules/schedule_names.dart';
import '../schedules/schedule_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'time_record_repository.dart';
import 'time_record_service.dart';

/// One weekday of the employee's schedule: the work window and the break.
typedef _DayPlan = ({String? start, String? finish, String? breakStart, String? breakFinish, int? breakMinutes});

/// The signed-in employee's own days for the Employee App: `GET /me/today`
/// (the "Today" screens) and `GET /me/period` (Period: day, week, month).
/// Every day is built exactly as on HR's Time records
/// ([TimeRecordService.daysOf]), so the employee and HR always see the same
/// status and times.
class MyDayService {
  MyDayService({
    required this._days,
    required this._records,
    required this._schedules,
    required this._clock,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TimeRecordService _days;
  final TimeRecordRepository _records;
  final ScheduleRepository _schedules;
  final WorkplaceClock _clock;
  final DateTime Function() _now;

  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  Future<MyDay> today(int userId) async {
    final date = _today();
    final day = (await _days.daysOf([_me(userId)], date, date)).where((d) => d.date == date).firstOrNull;
    final firstDay = !(await _records.firstRegistrations([userId])).containsKey(userId);
    final plan = (await _weekPlan(userId))[date.weekday];
    return MyDay(
      date: date,
      firstDay: firstDay && day == null,
      scheduledStart: plan?.start,
      scheduledFinish: plan?.finish,
      breakMinutes: plan?.breakMinutes,
      breakStart: plan?.breakStart,
      breakFinish: plan?.breakFinish,
      day: day,
      registeredMinutes: day == null ? null : registeredMinutes(day, plan?.breakMinutes ?? 0),
    );
  }

  /// Every day from [from] to [to] (workplace-local `yyyy-MM-dd`, both
  /// inclusive, at most [MyPeriod.maxDays]): the day as on Time records,
  /// the planned time from the schedule and the registered time of finished
  /// days, with the totals. 400 for a missing, malformed, reversed or too
  /// long period.
  Future<MyPeriod> period(int userId, String? from, String? to) async {
    final first = _parseDate(from, 'from');
    final last = _parseDate(to, 'to');
    if (last.isBefore(first)) throw const ApiException.validation('to', 'The period ends before it starts.');
    if (last.difference(first).inDays + 1 > MyPeriod.maxDays) {
      throw const ApiException.validation('to', 'A period can be at most ${MyPeriod.maxDays} days.');
    }
    final byDate = {for (final d in await _days.daysOf([_me(userId)], first, last)) d.date: d};
    final week = await _weekPlan(userId);
    final days = <MyPeriodDay>[];
    for (var date = first; !date.isAfter(last); date = DateTime.utc(date.year, date.month, date.day + 1)) {
      final plan = week[date.weekday];
      final day = byDate[date];
      days.add(
        MyPeriodDay(
          date: date,
          day: day,
          scheduledStart: plan?.start,
          scheduledFinish: plan?.finish,
          plannedMinutes: _planned(plan),
          registeredMinutes: day == null ? null : registeredMinutes(day, plan?.breakMinutes ?? 0),
        ),
      );
    }
    return MyPeriod(from: first, to: last, days: days);
  }

  /// Rounded finish − rounded start − break (D4, D13), never below zero;
  /// `null` while the day has no finish, a time is not rounded, or a
  /// correction waits for HR (D31).
  static int? registeredMinutes(TimeRecordDay day, int breakMinutes) {
    final start = day.start?.rounded;
    final finish = day.finish?.rounded;
    if (start == null || finish == null || day.pending.isNotEmpty) return null;
    final worked = finish.difference(start).inMinutes - breakMinutes;
    return worked < 0 ? 0 : worked;
  }

  /// The work window minus the break; `null` without a work window.
  static int? _planned(_DayPlan? plan) {
    final start = _minutes(plan?.start), finish = _minutes(plan?.finish);
    if (start == null || finish == null || finish <= start) return null;
    final planned = finish - start - (plan?.breakMinutes ?? 0);
    return planned < 0 ? 0 : planned;
  }

  /// The employee's schedule by ISO weekday (1 = Monday … 7 = Sunday).
  Future<Map<int, _DayPlan>> _weekPlan(int userId) async {
    final dayNames = {for (final d in await _schedules.listDays()) d.id: DayNames.weekdayOf(d.name)};
    final byWeekday = <int, List<UserScheduleRow>>{};
    for (final row in await _schedules.schedulesOf([userId])) {
      final weekday = dayNames[row.dayId];
      if (weekday != null) byWeekday.putIfAbsent(weekday, () => []).add(row);
    }
    return {
      for (final MapEntry(key: weekday, value: rows) in byWeekday.entries) weekday: _planOf(rows),
    };
  }

  static _DayPlan _planOf(List<UserScheduleRow> rows) {
    UserScheduleRow? of(String typeName) => rows.where((r) => r.typeName == typeName).firstOrNull;
    final start = of(ScheduleTypeNames.workStart);
    final finish = of(ScheduleTypeNames.workFinish);
    final breakRow = of(ScheduleTypeNames.breakTime);
    return (
      // Both work rows hold the day's window (D2b).
      start: start == null ? null : _hhmm(start.startHour, start.startMinute),
      finish: finish == null ? null : _hhmm(finish.stopHour, finish.stopMinute),
      breakStart: breakRow == null ? null : _hhmm(breakRow.startHour, breakRow.startMinute),
      breakFinish: breakRow == null ? null : _hhmm(breakRow.stopHour, breakRow.stopMinute),
      breakMinutes: breakRow == null
          ? null
          : (breakRow.stopHour * 60 + breakRow.stopMinute) - (breakRow.startHour * 60 + breakRow.startMinute),
    );
  }

  DateTime _today() {
    final local = _clock.wallClockOf(_now().toUtc());
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Only the days' registrations matter here: names, code and companies
  /// are not shown on the phone.
  static EmployeeSummary _me(int userId) => EmployeeSummary(
    id: userId,
    firstName: null,
    lastName: null,
    code: '',
    groups: const [],
    isActive: true,
    isActivated: true,
  );

  static int? _minutes(String? hhmm) {
    final match = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    return match == null ? null : int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  static DateTime _parseDate(String? value, String field) {
    if (value == null || !_date.hasMatch(value)) {
      throw ApiException.validation(field, 'Give "$field" as a date, e.g. 2026-10-22.');
    }
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  static String _hhmm(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
