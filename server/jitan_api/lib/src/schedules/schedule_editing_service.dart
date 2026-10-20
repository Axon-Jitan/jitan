import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'schedule_choices.dart';
import 'schedule_names.dart';
import 'schedule_service.dart';
import 'schedule_write_repository.dart';

/// One schedule row to create, before it exists.
typedef _NewRow = ({
  String typeName,
  int dayId,
  int startMinutes,
  int stopMinutes,
  int marginMinutes,
  int? intervalMinutes,
  bool? roundUp,
});

/// Saving and removing a group's work hours and breaks (roadmap phase 2,
/// decisions D2–D3b and D10–D13 in docs/TIME_ENGINE_ANALYSIS.md).
///
/// The ERD links schedules to employees (`tblUserSchedule`), so a group's
/// schedule is given to the employees it applies to: everyone who is only in
/// the group, and employees in several groups whose current schedule of
/// that kind comes from this group. A save creates fresh schedule rows,
/// moves those employees onto them and switches off the rows nobody uses any
/// more: nothing is changed in place or deleted, and registrations keep the
/// rounded times they were stored with. Saving what is already there changes
/// nothing. Every created or switched-off row is audited in the same
/// transaction.
class ScheduleEditingService {
  ScheduleEditingService({
    required this._writes,
    required this._schedules,
    required this._audit,
    required this._transactions,
  });

  final ScheduleWriteRepository _writes;
  final ScheduleService _schedules;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;

  static const _workTypes = [ScheduleTypeNames.workStart, ScheduleTypeNames.workFinish];
  static const _breakTypes = [ScheduleTypeNames.breakTime];
  static final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Sets [groupId]'s work hours, replacing any it had: per day a start and
  /// a finish, the arrival and leaving tolerance (attendance only), and the
  /// start and finish rounding (up or down by an interval, or none).
  Future<GroupSchedule> setWorkHours(int actorUserId, int groupId, SetWorkHoursRequest request) async {
    final rows = await _workRows(request);
    await _transactions.transaction((tx) => _replace(tx, actorUserId, groupId, _workTypes, rows));
    return _result(groupId);
  }

  /// Sets [groupId]'s whole schedule, its work hours and its break, in one
  /// transaction: when anything is refused, nothing is saved.
  ///
  /// HR only chooses the break's length. It is placed in the middle of each
  /// working day (decision D28): `start = (dayStart + dayFinish - length) / 2`,
  /// whole minutes, e.g. 08:00–16:30 with 30 minutes → 12:00–12:30. Only the
  /// length counts (breaks are deducted automatically); the stored time
  /// exists because a schedule row is a time from–to.
  Future<GroupSchedule> setSchedule(int actorUserId, int groupId, SetGroupScheduleRequest request) async {
    final workRows = await _workRows(request.workHours);
    final length = request.breakMinutes;
    _choice(length, ScheduleChoices.breakLengthMinutes, SetGroupScheduleRequest.fieldBreakMinutes);
    final days = {for (final row in workRows) row.dayId: (start: row.startMinutes, finish: row.stopMinutes)};
    final breakRows = <_NewRow>[];
    for (final MapEntry(key: dayId, value: (:start, :finish)) in days.entries) {
      if (length >= finish - start) {
        throw const ApiException.validation(
          SetGroupScheduleRequest.fieldBreakMinutes,
          'The break must be shorter than the working day.',
        );
      }
      final breakStart = (start + finish - length) ~/ 2;
      breakRows.add((
        typeName: ScheduleTypeNames.breakTime,
        dayId: dayId,
        startMinutes: breakStart,
        stopMinutes: breakStart + length,
        marginMinutes: 0,
        intervalMinutes: null,
        roundUp: null,
      ));
    }
    await _transactions.transaction((tx) async {
      if (!await _writes.lockGroup(tx, groupId)) throw ApiException.notFound('Group $groupId does not exist.');
      await _replace(tx, actorUserId, groupId, _workTypes, workRows, locked: true);
      await _replace(tx, actorUserId, groupId, _breakTypes, breakRows, locked: true);
    });
    return _result(groupId);
  }

  /// The schedule rows for [request]'s work hours, after checking it.
  Future<List<_NewRow>> _workRows(SetWorkHoursRequest request) async {
    await _validDayIds(request.days.map((d) => d.dayId), SetWorkHoursRequest.fieldDays);
    _tolerance(request.arrivalToleranceMinutes, SetWorkHoursRequest.fieldArrivalTolerance);
    _tolerance(request.leavingToleranceMinutes, SetWorkHoursRequest.fieldLeavingTolerance);
    for (final (rounding, field) in [
      (request.startRounding, SetWorkHoursRequest.fieldStartRounding),
      (request.finishRounding, SetWorkHoursRequest.fieldFinishRounding),
    ]) {
      if (rounding != null) _choice(rounding.intervalMinutes, ScheduleChoices.roundingIntervalMinutes, field);
    }
    final rows = <_NewRow>[];
    for (final day in request.days) {
      final start = _minutes(day.start, SetWorkHoursRequest.fieldDays);
      final finish = _minutes(day.finish, SetWorkHoursRequest.fieldDays);
      if (finish <= start) {
        throw const ApiException.validation(SetWorkHoursRequest.fieldDays, 'Finish must be after start.');
      }
      for (final (type, margin, rounding) in [
        (ScheduleTypeNames.workStart, request.arrivalToleranceMinutes, request.startRounding),
        (ScheduleTypeNames.workFinish, request.leavingToleranceMinutes, request.finishRounding),
      ]) {
        rows.add((
          typeName: type,
          dayId: day.dayId,
          startMinutes: start,
          stopMinutes: finish,
          marginMinutes: margin,
          intervalMinutes: rounding?.intervalMinutes,
          roundUp: rounding?.roundUp,
        ));
      }
    }
    return rows;
  }

  /// Removes [groupId]'s work hours (and nothing else).
  Future<GroupSchedule> removeWorkHours(int actorUserId, int groupId) async {
    await _transactions.transaction((tx) => _replace(tx, actorUserId, groupId, _workTypes, const []));
    return _result(groupId);
  }

  /// Sets [groupId]'s breaks, replacing any it had. Each break must lie
  /// within the group's work hours of that day.
  Future<GroupSchedule> setBreaks(int actorUserId, int groupId, SetBreaksRequest request) async {
    final rows = await _breakRows(request.days, SetBreaksRequest.fieldDays);
    await _transactions.transaction((tx) async {
      if (!await _writes.lockGroup(tx, groupId)) throw ApiException.notFound('Group $groupId does not exist.');
      _breaksWithin(rows, await _currentWorkHours(tx, groupId), SetBreaksRequest.fieldDays);
      await _replace(tx, actorUserId, groupId, _breakTypes, rows, locked: true);
    });
    return _result(groupId);
  }

  /// The schedule rows for [days]' breaks, after checking them; errors name
  /// [field].
  Future<List<_NewRow>> _breakRows(List<BreakDay> days, String field) async {
    await _validDayIds(days.map((d) => d.dayId), field);
    return [
      for (final day in days)
        (
          typeName: ScheduleTypeNames.breakTime,
          dayId: day.dayId,
          startMinutes: _minutes(day.usualStart, field),
          stopMinutes: _minutes(day.usualStart, field) + _breakLength(day.lengthMinutes, field),
          marginMinutes: 0,
          intervalMinutes: null,
          roundUp: null,
        ),
    ];
  }

  static int _breakLength(int minutes, String field) {
    _choice(minutes, ScheduleChoices.breakLengthMinutes, field);
    return minutes;
  }

  /// 400 unless every break lies within [hours] of its day.
  static void _breaksWithin(List<_NewRow> breaks, Map<int, ({int start, int finish})> hours, String field) {
    for (final row in breaks) {
      final day = hours[row.dayId];
      if (day == null || row.startMinutes < day.start || row.stopMinutes > day.finish) {
        throw ApiException.validation(field, 'The break must fall within the working hours.');
      }
    }
  }

  /// Removes [groupId]'s breaks.
  Future<GroupSchedule> removeBreaks(int actorUserId, int groupId) async {
    await _transactions.transaction((tx) => _replace(tx, actorUserId, groupId, _breakTypes, const []));
    return _result(groupId);
  }

  /// Gives the employees [groupId]'s schedule applies to exactly [rows] of
  /// the kinds [typeNames], in one transaction.
  Future<void> _replace(
    SqlExecutor tx,
    int actorUserId,
    int groupId,
    List<String> typeNames,
    List<_NewRow> rows, {
    bool locked = false,
  }) async {
    if (!locked && !await _writes.lockGroup(tx, groupId)) {
      throw ApiException.notFound('Group $groupId does not exist.');
    }
    final (employees: affected, links: links) = await _affected(tx, groupId, typeNames);

    // Saving what every affected employee already has changes nothing.
    final currentSets = _distinctSets(affected, links);
    if (currentSets.length == 1) {
      final shapes = await _writes.shapes(tx, currentSets.single);
      if (_sameRows(shapes, rows)) return;
    }

    final created = <int>[];
    final ruleIds = <(int?, bool?), int>{};
    for (final row in rows) {
      final typeId = await _typeId(tx, row.typeName);
      final scheduleId = await _writes.insertSchedule(
        tx,
        typeId: typeId,
        dayId: row.dayId,
        startMinutes: row.startMinutes,
        stopMinutes: row.stopMinutes,
        marginMinutes: row.marginMinutes,
      );
      created.add(scheduleId);
      int? ruleId;
      int? ruleLinkId;
      if (row.intervalMinutes case final interval?) {
        ruleId = ruleIds[(interval, row.roundUp)] ??=
            await _writes.insertRule(tx, intervalMinutes: interval, roundUp: row.roundUp!);
        ruleLinkId = await _writes.linkRule(tx, scheduleId, ruleId);
      }
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.scheduleCreated,
          actorUserId: actorUserId,
          references: {
            EventLogReference.schedule: scheduleId,
            EventLogReference.scheduleType: typeId,
            EventLogReference.day: row.dayId,
            EventLogReference.group: groupId,
            EventLogReference.roundingRule: ?ruleId,
            EventLogReference.scheduleRoundingRule: ?ruleLinkId,
          },
        ),
      );
    }

    await _writes.removeLinks(tx, [for (final l in links) l.userScheduleId]);
    for (final userId in affected) {
      for (final scheduleId in created) {
        await _writes.linkUser(tx, userId, scheduleId);
      }
    }
    for (final scheduleId in await _writes.unused(tx, {for (final l in links) l.scheduleId}.toList())) {
      await _writes.deactivateSchedules(tx, [scheduleId]);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.scheduleDeactivated,
          actorUserId: actorUserId,
          references: {EventLogReference.schedule: scheduleId, EventLogReference.group: groupId},
        ),
      );
    }
  }

  /// The employees [groupId]'s schedules of [typeNames] apply to, and their
  /// current links of those kinds. 409 when no employee is only in the group.
  Future<({List<int> employees, List<ScheduleLink> links})> _affected(
    SqlExecutor tx,
    int groupId,
    List<String> typeNames,
  ) async {
    final employees = await _writes.groupEmployees(tx, groupId);
    final single = [for (final e in employees) if (e.groupCount == 1) e.userId];
    if (single.isEmpty) {
      throw const ApiException(
        409,
        ApiErrorCode.groupWithoutEmployees,
        'Add an employee who is only in this group first.',
      );
    }
    final links = await _writes.currentLinks(tx, [for (final e in employees) e.userId], typeNames);
    final groupRows = {for (final l in links) if (single.contains(l.userId)) l.scheduleId};
    // An employee in several groups follows this group when all of their
    // schedules of these kinds are this group's rows.
    final followers = [
      for (final e in employees)
        if (e.groupCount > 1)
          if ([for (final l in links) if (l.userId == e.userId) l.scheduleId] case final own
              when own.isNotEmpty && own.every(groupRows.contains))
            e.userId,
    ];
    final affected = [...single, ...followers];
    return (employees: affected, links: [for (final l in links) if (affected.contains(l.userId)) l]);
  }

  /// The group's work hours per day, as minutes. 409 when its employees
  /// differ, because a break could not be checked against them.
  Future<Map<int, ({int start, int finish})>> _currentWorkHours(SqlExecutor tx, int groupId) async {
    final (employees: affected, links: links) = await _affected(tx, groupId, _workTypes);
    final sets = _distinctSets(affected, links);
    if (sets.length > 1) {
      throw const ApiException(
        409,
        ApiErrorCode.scheduleEmployeesDiffer,
        'The employees in this group have different work hours. Set the work hours first.',
      );
    }
    final hours = <int, ({int start, int finish})>{};
    for (final shape in await _writes.shapes(tx, sets.single.toList())) {
      final current = hours[shape.dayId];
      hours[shape.dayId] = switch (shape.typeName) {
        ScheduleTypeNames.workStart => (start: shape.startMinutes, finish: current?.finish ?? shape.stopMinutes),
        _ => (start: current?.start ?? shape.startMinutes, finish: shape.stopMinutes),
      };
    }
    return hours;
  }

  /// The different sets of schedule rows [userIds] have, each sorted.
  /// (Compared as text: Dart sets compare by identity.)
  static List<List<int>> _distinctSets(List<int> userIds, List<ScheduleLink> links) {
    final byKey = <String, List<int>>{};
    for (final userId in userIds) {
      final ids = [for (final l in links) if (l.userId == userId) l.scheduleId]..sort();
      byKey[ids.join(',')] = ids;
    }
    return byKey.values.toList();
  }

  Future<int> _typeId(SqlExecutor tx, String name) async {
    final ids = await _writes.typeIds(tx, name);
    if (ids.length != 1) {
      throw ApiException.configurationError(
        'tblScheduleType must have exactly one active row named "$name" (found ${ids.length}); '
        'see docs/database/reference_data.sql.',
      );
    }
    return ids.single;
  }

  Future<GroupSchedule> _result(int groupId) async =>
      await _schedules.groupSchedule(groupId) ?? (throw ApiException.notFound('Group $groupId does not exist.'));

  /// Whether the existing [shapes] are exactly the requested [rows].
  static bool _sameRows(List<ScheduleShape> shapes, List<_NewRow> rows) {
    String key(String type, int day, int start, int stop, int margin, int? interval, bool? up) =>
        '$type|$day|$start|$stop|$margin|$interval|$up';
    final existing = [
      for (final s in shapes)
        key(s.typeName, s.dayId, s.startMinutes, s.stopMinutes, s.marginMinutes, s.intervalMinutes, s.roundUp),
    ]..sort();
    final requested = [
      for (final r in rows) key(r.typeName, r.dayId, r.startMinutes, r.stopMinutes, r.marginMinutes, r.intervalMinutes, r.roundUp),
    ]..sort();
    return existing.join('\n') == requested.join('\n');
  }

  /// Checks the day IDs: at least one, each an active day, listed once.
  Future<void> _validDayIds(Iterable<int> dayIds, String field) async {
    final ids = dayIds.toList();
    if (ids.isEmpty) throw ApiException.validation(field, 'Choose at least one day.');
    final known = await _schedules.activeDays();
    if (ids.any((id) => !known.containsKey(id))) throw ApiException.validation(field, 'Choose days from the list.');
    if (ids.toSet().length != ids.length) throw ApiException.validation(field, 'Each day can be chosen once.');
  }

  static void _tolerance(int minutes, String field) {
    if (minutes < 0 || minutes > ScheduleChoices.maxToleranceMinutes) {
      throw ApiException.validation(field, 'Enter 0 to ${ScheduleChoices.maxToleranceMinutes} minutes.');
    }
  }

  static void _choice(int value, List<int> allowed, String field) {
    if (!allowed.contains(value)) throw ApiException.validation(field, 'Choose one of: ${allowed.join(', ')}.');
  }

  static int _minutes(String time, String field) {
    if (!_time.hasMatch(time)) throw ApiException.validation(field, 'Times are HH:mm, e.g. 08:00.');
    final [hours, minutes] = time.split(':').map(int.parse).toList();
    return hours * 60 + minutes;
  }
}
