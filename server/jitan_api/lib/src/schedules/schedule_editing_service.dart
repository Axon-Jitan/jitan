import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../time_registration/rounding/rounding_policy.dart';
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

  /// Sets [groupId]'s work hours, replacing any it had.
  Future<GroupSchedule> setWorkHours(int actorUserId, int groupId, SetWorkHoursRequest request) async {
    await _validDayIds(request.days.map((d) => d.dayId), SetWorkHoursRequest.fieldDays);
    _choice(request.startToleranceMinutes, ScheduleChoices.toleranceMinutes, SetWorkHoursRequest.fieldStartTolerance);
    _choice(request.finishToleranceMinutes, ScheduleChoices.toleranceMinutes, SetWorkHoursRequest.fieldFinishTolerance);
    _choice(request.startIntervalMinutes, ScheduleChoices.roundingIntervalMinutes, SetWorkHoursRequest.fieldStartInterval);
    _choice(request.finishIntervalMinutes, ScheduleChoices.roundingIntervalMinutes, SetWorkHoursRequest.fieldFinishInterval);
    final favour = switch (request.favour) {
      ScheduleRoundingFavour.company => RoundingFavour.company,
      ScheduleRoundingFavour.employee => RoundingFavour.employee,
      ScheduleRoundingFavour.mixed => throw const ApiException.validation(
          SetWorkHoursRequest.fieldFavour,
          'Choose who the rounding favours: the company or the employee.',
        ),
    };
    final rows = <_NewRow>[];
    for (final day in request.days) {
      final start = _minutes(day.start, SetWorkHoursRequest.fieldDays);
      final finish = _minutes(day.finish, SetWorkHoursRequest.fieldDays);
      if (finish <= start) {
        throw const ApiException.validation(SetWorkHoursRequest.fieldDays, 'Finish must be after start.');
      }
      for (final (type, boundary, margin, interval) in [
        (ScheduleTypeNames.workStart, RoundingBoundary.start, request.startToleranceMinutes, request.startIntervalMinutes),
        (ScheduleTypeNames.workFinish, RoundingBoundary.finish, request.finishToleranceMinutes, request.finishIntervalMinutes),
      ]) {
        rows.add((
          typeName: type,
          dayId: day.dayId,
          startMinutes: start,
          stopMinutes: finish,
          marginMinutes: margin,
          intervalMinutes: interval,
          roundUp: favour.directionFor(boundary) == RoundingDirection.up,
        ));
      }
    }
    await _transactions.transaction((tx) => _replace(tx, actorUserId, groupId, _workTypes, rows));
    return _result(groupId);
  }

  /// Removes [groupId]'s work hours (and nothing else).
  Future<GroupSchedule> removeWorkHours(int actorUserId, int groupId) async {
    await _transactions.transaction((tx) => _replace(tx, actorUserId, groupId, _workTypes, const []));
    return _result(groupId);
  }

  /// Sets [groupId]'s breaks, replacing any it had. Each break must lie
  /// within the group's work hours of that day.
  Future<GroupSchedule> setBreaks(int actorUserId, int groupId, SetBreaksRequest request) async {
    await _validDayIds(request.days.map((d) => d.dayId), SetBreaksRequest.fieldDays);
    final rows = <_NewRow>[];
    for (final day in request.days) {
      final start = _minutes(day.usualStart, SetBreaksRequest.fieldDays);
      _choice(day.lengthMinutes, ScheduleChoices.breakLengthMinutes, SetBreaksRequest.fieldDays);
      rows.add((
        typeName: ScheduleTypeNames.breakTime,
        dayId: day.dayId,
        startMinutes: start,
        stopMinutes: start + day.lengthMinutes,
        marginMinutes: 0,
        intervalMinutes: null,
        roundUp: null,
      ));
    }
    await _transactions.transaction((tx) async {
      if (!await _writes.lockGroup(tx, groupId)) throw ApiException.notFound('Group $groupId does not exist.');
      final workHours = await _currentWorkHours(tx, groupId);
      for (final row in rows) {
        final hours = workHours[row.dayId];
        if (hours == null || row.startMinutes < hours.start || row.stopMinutes > hours.finish) {
          throw const ApiException.validation(SetBreaksRequest.fieldDays, 'The break must fall within the working hours.');
        }
      }
      await _replace(tx, actorUserId, groupId, _breakTypes, rows, locked: true);
    });
    return _result(groupId);
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

  static void _choice(int value, List<int> allowed, String field) {
    if (!allowed.contains(value)) throw ApiException.validation(field, 'Choose one of: ${allowed.join(', ')}.');
  }

  static int _minutes(String time, String field) {
    if (!_time.hasMatch(time)) throw ApiException.validation(field, 'Times are HH:mm, e.g. 08:00.');
    final [hours, minutes] = time.split(':').map(int.parse).toList();
    return hours * 60 + minutes;
  }
}
