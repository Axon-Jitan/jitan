import '../schedules/schedule_names.dart';
import '../schedules/schedule_repository.dart';

/// One weekday of an employee's schedule: the work window and the break.
typedef DayPlan = ({String? start, String? finish, String? breakStart, String? breakFinish, int? breakMinutes});

/// Employees' schedules by ISO weekday (1 = Monday … 7 = Sunday), as the
/// phone's Today and Period and HR's reports read them.
class WeekPlans {
  const WeekPlans(this._schedules);

  final ScheduleRepository _schedules;

  /// userID → weekday → plan.
  Future<Map<int, Map<int, DayPlan>>> of(List<int> userIds) async {
    if (userIds.isEmpty) return const {};
    final dayNames = {for (final d in await _schedules.listDays()) d.id: DayNames.weekdayOf(d.name)};
    final rows = <int, Map<int, List<UserScheduleRow>>>{};
    for (final row in await _schedules.schedulesOf(userIds)) {
      final weekday = dayNames[row.dayId];
      if (weekday != null) rows.putIfAbsent(row.userId, () => {}).putIfAbsent(weekday, () => []).add(row);
    }
    return {
      for (final MapEntry(key: userId, value: week) in rows.entries)
        userId: {for (final MapEntry(key: weekday, value: dayRows) in week.entries) weekday: _planOf(dayRows)},
    };
  }

  /// The work window minus the break; `null` without a work window.
  static int? plannedMinutes(DayPlan? plan) {
    final start = _minutes(plan?.start), finish = _minutes(plan?.finish);
    if (start == null || finish == null || finish <= start) return null;
    final planned = finish - start - (plan?.breakMinutes ?? 0);
    return planned < 0 ? 0 : planned;
  }

  static DayPlan _planOf(List<UserScheduleRow> rows) {
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

  static int? _minutes(String? hhmm) {
    final match = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    return match == null ? null : int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  static String _hhmm(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
