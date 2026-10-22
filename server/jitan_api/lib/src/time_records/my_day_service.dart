import 'package:jitan_models/jitan_models.dart';

import '../schedules/schedule_names.dart';
import '../schedules/schedule_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'time_record_repository.dart';
import 'time_record_service.dart';

/// `GET /me/today`: the signed-in employee's day for the Employee App
/// "Today" screens. The day itself is built exactly as on HR's Time records
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

  Future<MyDay> today(int userId) async {
    final local = _clock.wallClockOf(_now().toUtc());
    final date = DateTime.utc(local.year, local.month, local.day);

    // Only the day's registrations matter here: names, code and companies
    // are not shown on the phone.
    final me = EmployeeSummary(
      id: userId,
      firstName: null,
      lastName: null,
      code: '',
      groups: const [],
      isActive: true,
      isActivated: true,
    );
    final day = (await _days.daysOf([me], date, date)).where((d) => d.date == date).firstOrNull;
    final firstDay = !(await _records.firstRegistrations([userId])).containsKey(userId);

    final dayNames = {for (final d in await _schedules.listDays()) d.id: DayNames.weekdayOf(d.name)};
    final rows = [
      for (final row in await _schedules.schedulesOf([userId]))
        if (dayNames[row.dayId] == date.weekday) row,
    ];
    UserScheduleRow? of(String typeName) => rows.where((r) => r.typeName == typeName).firstOrNull;
    final start = of(ScheduleTypeNames.workStart);
    final finish = of(ScheduleTypeNames.workFinish);
    final breakRow = of(ScheduleTypeNames.breakTime);
    final breakMinutes = breakRow == null
        ? null
        : (breakRow.stopHour * 60 + breakRow.stopMinute) - (breakRow.startHour * 60 + breakRow.startMinute);

    return MyDay(
      date: date,
      firstDay: firstDay && day == null,
      // Both work rows hold the day's window (D2b).
      scheduledStart: start == null ? null : _hhmm(start.startHour, start.startMinute),
      scheduledFinish: finish == null ? null : _hhmm(finish.stopHour, finish.stopMinute),
      breakMinutes: breakMinutes,
      day: day,
      registeredMinutes: day == null ? null : registeredMinutes(day, breakMinutes ?? 0),
    );
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

  static String _hhmm(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
