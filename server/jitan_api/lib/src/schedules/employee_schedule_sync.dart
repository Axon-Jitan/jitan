import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'schedule_names.dart';
import 'schedule_write_repository.dart';

/// Keeps an employee's schedules in line with their groups (roadmap phase
/// 2, step 4; decisions D2–D3b in docs/TIME_ENGINE_ANALYSIS.md).
///
/// A group's schedule is what its other employees **who are only in that
/// group** have. After a change of an employee's groups:
///
/// - **one group**: the employee gets that group's schedule. When those
///   employees differ, nothing is picked: the employee keeps what they had,
///   and HR sees the difference on the Schedules screen. A group whose
///   only-member is this employee has no schedule, so they get none.
/// - **no group**: no schedule.
/// - **several groups**: the employee keeps their schedule while it still
///   belongs to one of their groups; one from a group they left is switched
///   off, and HR chooses the source ([useGroup], "Schedules come from").
///
/// Runs in the caller's transaction, after the employee's row is locked.
/// Links are switched off, never deleted, so `tblUserSchedule` keeps the
/// history; the group change itself is audited by the caller. Schedule rows
/// nobody uses any more are switched off and audited.
///
/// Group rows are deliberately not locked here (DB-DRIVER-01: assignment
/// transactions take only the employee lock). If HR saves the group's
/// schedule at the same moment, the new member may keep the previous rows
/// until the group's next save.
class EmployeeScheduleSync {
  const EmployeeScheduleSync({
    this._writes = const ScheduleWriteRepository(),
    this._audit = const AuditLogRepository(),
  });

  final ScheduleWriteRepository _writes;
  final AuditLogRepository _audit;

  /// Every kind of schedule a group gives its employees.
  static const _types = ScheduleTypeNames.all;

  /// Brings [userId]'s schedules in line with their current groups.
  Future<void> afterGroupChange(SqlExecutor tx, int actorUserId, int userId) async {
    final groups = await _writes.groupsOf(tx, userId);
    final own = await _writes.currentLinks(tx, [userId], _types);
    final ownRows = {for (final l in own) l.scheduleId};

    switch (groups) {
      case []:
        await _replace(tx, actorUserId, userId, own, const []);
      case [final group]:
        final schedule = await _groupSchedule(tx, group, userId);
        if (schedule.differs) return;
        await _replace(tx, actorUserId, userId, own, schedule.rows);
      default:
        if (ownRows.isEmpty) return;
        for (final group in groups) {
          if (ownRows.every((await _groupSchedule(tx, group, userId)).allRows.contains)) return;
        }
        await _replace(tx, actorUserId, userId, own, const []);
    }
  }

  /// "Schedules come from [groupId]": gives [userId] that group's schedule.
  /// 400 when the employee is not in the group; 409 when the group has no
  /// employee only in it, or those employees differ.
  Future<void> useGroup(SqlExecutor tx, int actorUserId, int userId, int groupId) async {
    if (!(await _writes.groupsOf(tx, userId)).contains(groupId)) {
      throw const ApiException.validation(ScheduleSourceRequest.fieldGroupId, 'Choose one of the employee\'s groups.');
    }
    final schedule = await _groupSchedule(tx, groupId, userId);
    if (!schedule.hasEmployees) {
      throw const ApiException(409, ApiErrorCode.groupWithoutEmployees, 'Add an employee who is only in this group first.');
    }
    if (schedule.differs) {
      throw const ApiException(
        409,
        ApiErrorCode.scheduleEmployeesDiffer,
        'The employees in this group have different schedules. Save the group\'s schedule first.',
      );
    }
    final own = await _writes.currentLinks(tx, [userId], _types);
    await _replace(tx, actorUserId, userId, own, schedule.rows);
    await _audit.record(
      tx,
      AuditEvent(
        type: AuditEventType.scheduleSourceChanged,
        actorUserId: actorUserId,
        references: {EventLogReference.user: userId, EventLogReference.group: groupId},
      ),
    );
  }

  /// The group of [userId]'s schedule: the one of their groups that holds
  /// all their schedule rows; `null` without a schedule, or when it is not
  /// exactly one group's.
  Future<int?> currentSource(SqlExecutor executor, int userId) async {
    final ownRows = {for (final l in await _writes.currentLinks(executor, [userId], _types)) l.scheduleId};
    if (ownRows.isEmpty) return null;
    final sources = [
      for (final group in await _writes.groupsOf(executor, userId))
        if (ownRows.every((await _groupSchedule(executor, group, userId)).allRows.contains)) group,
    ];
    return sources.length == 1 ? sources.single : null;
  }

  /// [groupId]'s schedule as its employees only in it (other than
  /// [exceptUserId]) have it.
  Future<({bool hasEmployees, bool differs, List<int> rows, Set<int> allRows})> _groupSchedule(
    SqlExecutor tx,
    int groupId,
    int exceptUserId,
  ) async {
    final single = [
      for (final e in await _writes.groupEmployees(tx, groupId))
        if (e.groupCount == 1 && e.userId != exceptUserId) e.userId,
    ];
    if (single.isEmpty) return (hasEmployees: false, differs: false, rows: const <int>[], allRows: const <int>{});
    final links = await _writes.currentLinks(tx, single, _types);
    final sets = <String, List<int>>{};
    for (final userId in single) {
      final ids = [for (final l in links) if (l.userId == userId) l.scheduleId]..sort();
      sets[ids.join(',')] = ids;
    }
    return (
      hasEmployees: true,
      differs: sets.length > 1,
      rows: sets.length == 1 ? sets.values.single : const <int>[],
      allRows: {for (final l in links) l.scheduleId},
    );
  }

  /// Makes [userId]'s links exactly [target]: links not in it are switched
  /// off, missing ones added; rows nobody uses any more are switched off.
  Future<void> _replace(SqlExecutor tx, int actorUserId, int userId, List<ScheduleLink> own, List<int> target) async {
    final keep = target.toSet();
    final removed = [for (final l in own) if (!keep.contains(l.scheduleId)) l];
    final have = {for (final l in own) l.scheduleId};
    await _writes.removeLinks(tx, [for (final l in removed) l.userScheduleId]);
    for (final scheduleId in target) {
      if (!have.contains(scheduleId)) await _writes.linkUser(tx, userId, scheduleId);
    }
    for (final scheduleId in await _writes.unused(tx, [for (final l in removed) l.scheduleId])) {
      await _writes.deactivateSchedules(tx, [scheduleId]);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.scheduleDeactivated,
          actorUserId: actorUserId,
          references: {EventLogReference.schedule: scheduleId, EventLogReference.user: userId},
        ),
      );
    }
  }
}
