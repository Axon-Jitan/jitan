import '../http/api_exception.dart';
import '../schedules/schedule_names.dart';
import '../schedules/schedule_repository.dart';
import 'rounding/rounding_policy.dart';

/// The rounding of one employee's working day, read from the schedule they
/// have for that weekday (TIME_ENGINE_ANALYSIS D10, D11a): the "Work – start"
/// and "Work – finish" rows of the day and the `tblRoundingRule` linked to
/// each. No schedule that day, or no rule, means no rounding.
class RegistrationRounding {
  const RegistrationRounding(this._schedules);

  final ScheduleRepository _schedules;

  /// The policy of [userId] on ISO [weekday] (1 = Monday … 7 = Sunday).
  ///
  /// A configuration error (never a guess, ENGINEERING_RULES §20) when the
  /// employee has two schedules of one kind that day, two rules on one
  /// schedule, or an interval HR can't choose.
  Future<RoundingPolicy> policyOn(int userId, int weekday) async {
    final days = {for (final day in await _schedules.listDays()) day.id: DayNames.weekdayOf(day.name)};
    final today = [
      for (final row in await _schedules.schedulesOf([userId]))
        if (days[row.dayId] == weekday) row,
    ];
    final start = _single(today, ScheduleTypeNames.workStart);
    final finish = _single(today, ScheduleTypeNames.workFinish);
    final rules = await _schedules.rulesOf([?start, ?finish]);
    return RoundingPolicy(start: _rule(rules, start), finish: _rule(rules, finish));
  }

  static int? _single(List<UserScheduleRow> rows, String typeName) {
    final ids = {for (final row in rows) if (row.typeName == typeName) row.scheduleId};
    if (ids.length > 1) {
      throw ApiException.configurationError('An employee has several "$typeName" schedules on one day.');
    }
    return ids.firstOrNull;
  }

  static RoundingRule? _rule(List<ScheduleRuleRow> rules, int? scheduleId) {
    if (scheduleId == null) return null;
    final linked = [for (final r in rules) if (r.scheduleId == scheduleId) r];
    if (linked.isEmpty) return null;
    if (linked.length > 1) {
      throw ApiException.configurationError('Schedule $scheduleId has several rounding rules.');
    }
    final interval = RoundingInterval.fromMinutes(linked.single.intervalMinutes) ??
        (throw ApiException.configurationError(
          'Schedule $scheduleId rounds every ${linked.single.intervalMinutes} minutes, which is not an allowed interval.',
        ));
    return RoundingRule(
      interval: interval,
      direction: linked.single.roundUp ? RoundingDirection.up : RoundingDirection.down,
    );
  }
}
