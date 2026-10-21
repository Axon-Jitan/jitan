import 'package:jitan_models/jitan_models.dart';

import '../groups/group_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'group_schedule_link_repository.dart';
import 'schedule_choices.dart';
import 'schedule_names.dart';
import 'schedule_repository.dart';

/// Reading schedules (decisions D2–D3b, D10–D13 in
/// docs/TIME_ENGINE_ANALYSIS.md). Schedules are set per employee group, but
/// the ERD links schedules to employees only (`tblUserSchedule`). A group's
/// schedules are therefore the ones its employees **who are only in that
/// group** have. When they differ, every set is returned as a variant and
/// none is picked (ENGINEERING_RULES §20).
///
/// With [_groupLinks] and [_db] (PROPOSAL, ERD_GAPS GAP-15, local database
/// only) a group's schedule is its own rows in `tblGroupSchedule`: a group
/// has hours or not, its employees cannot differ, and an empty group can
/// have hours.
class ScheduleService {
  ScheduleService({required this._schedules, required this._groups, this._groupLinks, this._db})
    : assert((_groupLinks == null) == (_db == null), 'group links need the database');

  final ScheduleRepository _schedules;
  final GroupRepository _groups;
  final GroupScheduleLinkRepository? _groupLinks;
  final SqlExecutor? _db;

  /// The fixed choices of the schedule form, with the days Monday first.
  Future<ScheduleOptions> options() async => ScheduleOptions(
        days: (await activeDays()).values.toList()..sort((a, b) => a.weekday.compareTo(b.weekday)),
        roundingIntervalMinutes: ScheduleChoices.roundingIntervalMinutes,
        maxToleranceMinutes: ScheduleChoices.maxToleranceMinutes,
        breakLengthMinutes: ScheduleChoices.breakLengthMinutes,
      );

  /// Every active group with its schedules, by group name.
  Future<List<GroupSchedule>> groupSchedules() async {
    final days = await activeDays();
    final groups = await _groups.listActive();
    final members = <int, Set<int>>{};
    for (final member in await _schedules.singleGroupMembers()) {
      members.putIfAbsent(member.groupId, () => {}).add(member.userId);
    }
    if (_groupLinks case final groupLinks?) return _ownedSchedules(groupLinks, groups, members, days);
    final rows = await _schedules.schedulesOf(members.values.expand((ids) => ids));
    final scheduleIdsOf = <int, Set<int>>{};
    final scheduleById = <int, UserScheduleRow>{};
    for (final row in rows) {
      scheduleIdsOf.putIfAbsent(row.userId, () => {}).add(row.scheduleId);
      scheduleById[row.scheduleId] = row;
    }
    final rulesOf = <int, List<ScheduleRuleRow>>{};
    for (final rule in await _schedules.rulesOf(scheduleById.keys)) {
      rulesOf.putIfAbsent(rule.scheduleId, () => []).add(rule);
    }

    return [
      for (final group in groups)
        _groupSchedule(group, members[group.id] ?? const {}, scheduleIdsOf, scheduleById, rulesOf, days),
    ];
  }

  GroupSchedule _groupSchedule(
    GroupSummary group,
    Set<int> userIds,
    Map<int, Set<int>> scheduleIdsOf,
    Map<int, UserScheduleRow> scheduleById,
    Map<int, List<ScheduleRuleRow>> rulesOf,
    Map<int, ScheduleDay> days,
  ) {
    if (userIds.isEmpty) {
      return GroupSchedule(
        group: group,
        status: GroupScheduleStatus.noSingleGroupEmployees,
        singleGroupEmployeeCount: 0,
        variants: const [],
      );
    }
    // Employees with the same set of schedule rows share one variant.
    final employeesPerSet = <String, ({List<int> scheduleIds, int count})>{};
    for (final userId in userIds) {
      final ids = (scheduleIdsOf[userId] ?? const <int>{}).toList()..sort();
      final key = ids.join(',');
      final current = employeesPerSet[key];
      employeesPerSet[key] = (scheduleIds: ids, count: (current?.count ?? 0) + 1);
    }
    final sets = employeesPerSet.values.toList()
      ..sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : a.scheduleIds.join(',').compareTo(b.scheduleIds.join(',')));

    if (sets.length == 1 && sets.single.scheduleIds.isEmpty) {
      return GroupSchedule(
        group: group,
        status: GroupScheduleStatus.noSchedule,
        singleGroupEmployeeCount: userIds.length,
        variants: const [],
      );
    }
    return GroupSchedule(
      group: group,
      status: sets.length == 1 ? GroupScheduleStatus.configured : GroupScheduleStatus.employeesDiffer,
      singleGroupEmployeeCount: userIds.length,
      variants: [
        for (final set in sets)
          _variant(group.name, set.count, [for (final id in set.scheduleIds) _rowOf(scheduleById[id]!)], rulesOf, days),
      ],
    );
  }

  /// GAP-15: each group's own rows, one variant or none.
  Future<List<GroupSchedule>> _ownedSchedules(
    GroupScheduleLinkRepository groupLinks,
    List<GroupSummary> groups,
    Map<int, Set<int>> members,
    Map<int, ScheduleDay> days,
  ) async {
    final rowsOf = <int, List<_Row>>{};
    for (final row in await groupLinks.rowsOfGroups(_db!)) {
      rowsOf.putIfAbsent(row.groupId, () => []).add((
        scheduleId: row.scheduleId,
        typeName: row.typeName,
        dayId: row.dayId,
        startHour: row.startHour,
        startMinute: row.startMinute,
        stopHour: row.stopHour,
        stopMinute: row.stopMinute,
        marginMinutes: row.marginMinutes,
      ));
    }
    final rulesOf = <int, List<ScheduleRuleRow>>{};
    for (final rule in await _schedules.rulesOf(rowsOf.values.expand((rows) => rows).map((r) => r.scheduleId))) {
      rulesOf.putIfAbsent(rule.scheduleId, () => []).add(rule);
    }
    return [
      for (final group in groups)
        switch ((rowsOf[group.id] ?? const <_Row>[], members[group.id]?.length ?? 0)) {
          (final rows, final count) when rows.isEmpty => GroupSchedule(
            group: group,
            status: GroupScheduleStatus.noSchedule,
            singleGroupEmployeeCount: count,
            variants: const [],
          ),
          (final rows, final count) => GroupSchedule(
            group: group,
            status: GroupScheduleStatus.configured,
            singleGroupEmployeeCount: count,
            variants: [_variant(group.name, count, rows, rulesOf, days)],
          ),
        },
    ];
  }

  /// The hours each of [userIds] currently has (`tblUserSchedule`), for the
  /// Employees list; employees without hours are left out.
  Future<Map<int, ScheduleVariant>> employeeSchedules(Iterable<int> userIds) async {
    final rows = await _schedules.schedulesOf(userIds);
    if (rows.isEmpty) return const {};
    final days = await activeDays();
    final rulesOf = <int, List<ScheduleRuleRow>>{};
    for (final rule in await _schedules.rulesOf(rows.map((r) => r.scheduleId))) {
      rulesOf.putIfAbsent(rule.scheduleId, () => []).add(rule);
    }
    final byUser = <int, List<_Row>>{};
    for (final row in rows) {
      byUser.putIfAbsent(row.userId, () => []).add(_rowOf(row));
    }
    return {
      for (final MapEntry(key: userId, value: own) in byUser.entries)
        userId: _variant('Employee $userId', 1, own, rulesOf, days),
    };
  }

  ScheduleVariant _variant(
    String owner,
    int employeeCount,
    List<_Row> rows,
    Map<int, List<ScheduleRuleRow>> rulesOf,
    Map<int, ScheduleDay> days,
  ) {
    final starts = <int, WorkBoundary>{};
    final finishes = <int, WorkBoundary>{};
    final breaks = <int, BreakSchedule>{};
    void add<T>(Map<int, T> byDay, int dayId, T value, String what) {
      if (byDay.containsKey(dayId)) {
        throw ApiException.configurationError(
          '$owner has two "$what" schedules on ${days[dayId]?.name ?? 'day $dayId'}; one is expected.',
        );
      }
      byDay[dayId] = value;
    }

    for (final row in rows) {
      final day = days[row.dayId] ??
          (throw ApiException.configurationError('Schedule ${row.scheduleId} is on an unknown day ${row.dayId}.'));
      switch (row.typeName) {
        case ScheduleTypeNames.workStart:
          add(starts, day.id, _boundary(_time(row.startHour, row.startMinute), row, rulesOf), row.typeName);
        case ScheduleTypeNames.workFinish:
          add(finishes, day.id, _boundary(_time(row.stopHour, row.stopMinute), row, rulesOf), row.typeName);
        case ScheduleTypeNames.breakTime:
          add(
            breaks,
            day.id,
            BreakSchedule(
              day: day,
              usualStart: _time(row.startHour, row.startMinute),
              lengthMinutes: (row.stopHour * 60 + row.stopMinute) - (row.startHour * 60 + row.startMinute),
            ),
            row.typeName,
          );
      }
    }

    final workDayIds = {...starts.keys, ...finishes.keys}.toList()..sort((a, b) => days[a]!.weekday.compareTo(days[b]!.weekday));
    return ScheduleVariant(
      employeeCount: employeeCount,
      workDays: [
        for (final id in workDayIds) WorkDaySchedule(day: days[id]!, start: starts[id], finish: finishes[id]),
      ],
      breaks: breaks.values.toList()..sort((a, b) => a.day.weekday.compareTo(b.day.weekday)),
    );
  }

  /// A start or finish with its tolerance and its rounding rule: none when no
  /// rule is linked (not rounded), or when several are (a data problem: HR
  /// sees no rounding and saves it again).
  static WorkBoundary _boundary(String time, _Row row, Map<int, List<ScheduleRuleRow>> rulesOf) {
    final rules = rulesOf[row.scheduleId] ?? const [];
    return WorkBoundary(
      time: time,
      toleranceMinutes: row.marginMinutes,
      rounding: rules.length == 1
          ? ScheduleRounding(intervalMinutes: rules.single.intervalMinutes, roundUp: rules.single.roundUp)
          : null,
    );
  }

  /// One active group with its schedules; `null` when it is not active.
  Future<GroupSchedule?> groupSchedule(int groupId) async =>
      (await groupSchedules()).where((g) => g.group.id == groupId).firstOrNull;

  /// The active days by ID. A day name Jitan doesn't know, or two rows for
  /// one weekday, is a configuration error, not a guess.
  Future<Map<int, ScheduleDay>> activeDays() async {
    final days = <int, ScheduleDay>{};
    final seen = <int>{};
    for (final row in await _schedules.listDays()) {
      final weekday = DayNames.weekdayOf(row.name) ??
          (throw ApiException.configurationError('tblDays has an unknown day name "${row.name}".'));
      if (!seen.add(weekday)) {
        throw ApiException.configurationError('tblDays has more than one active "${row.name}".');
      }
      days[row.id] = ScheduleDay(id: row.id, name: row.name, weekday: weekday);
    }
    return days;
  }

  static _Row _rowOf(UserScheduleRow row) => (
    scheduleId: row.scheduleId,
    typeName: row.typeName,
    dayId: row.dayId,
    startHour: row.startHour,
    startMinute: row.startMinute,
    stopHour: row.stopHour,
    stopMinute: row.stopMinute,
    marginMinutes: row.marginMinutes,
  );

  static String _time(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// One schedule row, whoever has it (an employee or, with GAP-15, a group).
typedef _Row = ({
  int scheduleId,
  String typeName,
  int dayId,
  int startHour,
  int startMinute,
  int stopHour,
  int stopMinute,
  int marginMinutes,
});
