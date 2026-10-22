import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../employees/employee_assignment_repository.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import '../schedules/employee_schedule_sync.dart';
import 'group_member_repository.dart';

/// A group's members, from every company (groups are shared by all
/// companies; product owner, 2026-10-21): listing them, finding employees to
/// add, adding and removing.
///
/// Access stays per company: an employee is listed only when HR may see
/// employees of one of their companies, and adding or removing needs the
/// right to manage assignments in **every** company the employee belongs to,
/// because a group applies across all of them (as for credential groups).
/// In V1 HR and Admin hold these rights everywhere (decision 2026-10-13); the
/// checks keep a narrower role possible later.
///
/// Every change writes the `tblUserGroup` link and its `tblEventLog` row in
/// one transaction, and the employee's schedules follow their groups
/// (EmployeeScheduleSync), exactly as in Manage employee assignments.
class GroupMemberService {
  GroupMemberService({
    required this._members,
    required this._assignments,
    required this._employees,
    required this._audit,
    required this._scheduleSync,
    required this._transactions,
  });

  final GroupMemberRepository _members;
  final EmployeeAssignmentRepository _assignments;
  final EmployeeRepository _employees;
  final AuditLogRepository _audit;
  final EmployeeScheduleSync _scheduleSync;
  final TransactionRunner _transactions;

  /// The most employees added in one request.
  static const maxIds = 100;
  static const _deadlockAttempts = 3;

  /// [groupId]'s members, each with the group their work hours come from
  /// (EmployeeScheduleSync.currentSource), so the group page can show who
  /// works its hours and who still needs HR's choice.
  Future<List<GroupMember>> members(int groupId, {required Future<bool> Function(int companyId) mayView}) async {
    await _requireGroup(groupId);
    final members = await _withDetails(await _members.members(groupId), mayView);
    final sources = await _transactions.transaction(
      (tx) async => {for (final m in members) m.id: await _scheduleSync.currentSource(tx, m.id)},
    );
    final names = await _members.groupNames([...sources.values.whereType<int>().toSet()]);
    return [
      for (final m in members)
        GroupMember(
          id: m.id,
          firstName: m.firstName,
          lastName: m.lastName,
          code: m.code,
          companies: m.companies,
          companyIds: m.companyIds,
          groups: m.groups,
          hoursFromGroupId: sources[m.id],
          hoursFromGroup: names[sources[m.id]],
        ),
    ];
  }

  /// Employees not yet in [groupId] that HR may add, matching [search];
  /// without [groupId], for a group still being created.
  Future<List<GroupMember>> candidates(
    int? groupId, {
    String? search,
    required Future<bool> Function(int companyId) mayView,
  }) async {
    if (groupId != null) await _requireGroup(groupId);
    final trimmed = search?.trim();
    return _withDetails(await _members.candidates(groupId, search: trimmed == null || trimmed.isEmpty ? null : trimmed), mayView);
  }

  /// Adds [userIds] to [groupId] (an active group): new links, or removed
  /// ones reactivated; employees already in it are skipped and not audited
  /// again. All or nothing.
  ///
  /// [followIds] (of [userIds]): employees already in other groups whose
  /// hours come from [groupId] from now on ("Use {group} hours", Figma
  /// `1390:1106`); the others keep theirs.
  Future<List<GroupMember>> add(
    int actorUserId,
    int groupId,
    List<int> userIds, {
    List<int> followIds = const [],
    required Future<void> Function(int companyId) mayManage,
    required Future<bool> Function(int companyId) mayView,
  }) async {
    final ids = validIds(userIds, AddAssignmentsRequest.fieldIds);
    final follow = validFollowIds(followIds, ids, AddGroupMembersRequest.fieldFollowIds);
    if (await _requireGroup(groupId) == false) {
      throw const ApiException.validation(AddAssignmentsRequest.fieldIds, 'The group is deactivated; reactivate it first.');
    }
    await requireMayManage(ids, mayManage);
    await _retryOnDeadlock((tx) async {
      await addIn(tx, actorUserId, groupId, ids);
      await followIn(tx, actorUserId, groupId, follow);
    });
    return members(groupId, mayView: mayView);
  }

  /// [userIds] without repeats, in ID order; 400 on [field] when empty, too
  /// many or not IDs.
  static List<int> validIds(List<int> userIds, String field) {
    final ids = userIds.toSet().toList()..sort();
    if (ids.isEmpty || ids.length > maxIds || ids.any((id) => id <= 0)) {
      throw ApiException.validation(field, 'Choose at least one employee.');
    }
    return ids;
  }

  /// Adds [ids] (from [validIds], permission checked) to [groupId] inside
  /// the caller's transaction [tx].
  Future<void> addIn(SqlExecutor tx, int actorUserId, int groupId, List<int> ids) async {
    // In ID order, so two concurrent saves lock the employees the same way.
    for (final userId in ids) {
      if (!await _employees.lockUser(tx, userId)) throw ApiException.notFound('Employee $userId does not exist.');
      final userGroupId = await _assignments.addGroup(tx, userId, groupId);
      if (userGroupId == null) continue;
      await _record(tx, AuditEventType.groupAssigned, actorUserId, userId, groupId, userGroupId);
      await _scheduleSync.afterGroupChange(tx, actorUserId, userId);
    }
  }

  /// [followIds] without repeats; 400 on [field] when one is not among [ids].
  static List<int> validFollowIds(List<int> followIds, List<int> ids, String field) {
    final follow = followIds.toSet().toList()..sort();
    if (follow.any((id) => !ids.contains(id))) {
      throw ApiException.validation(field, 'Only employees being added can use this group\'s hours.');
    }
    return follow;
  }

  /// Gives [ids] (already in [groupId]) the group's hours inside the
  /// caller's transaction [tx], audited as a change of schedule source.
  Future<void> followIn(SqlExecutor tx, int actorUserId, int groupId, List<int> ids) async {
    for (final userId in ids) {
      await _scheduleSync.useGroup(tx, actorUserId, userId, groupId);
    }
  }

  /// The current groups (names) of each of [userIds]; Create group checks
  /// that someone will be only in the new group.
  Future<Map<int, List<String>>> groupsOf(List<int> userIds) => _members.groupsOf(userIds);

  /// Removes [userId] from [groupId] (soft delete). Removing someone who is
  /// not in the group changes nothing.
  Future<List<GroupMember>> remove(
    int actorUserId,
    int groupId,
    int userId, {
    required Future<void> Function(int companyId) mayManage,
    required Future<bool> Function(int companyId) mayView,
  }) async {
    await _requireGroup(groupId);
    await requireMayManage([userId], mayManage);
    await _retryOnDeadlock((tx) async {
      if (!await _employees.lockUser(tx, userId)) throw ApiException.notFound('Employee $userId does not exist.');
      final userGroupId = await _assignments.removeGroup(tx, userId, groupId);
      if (userGroupId == null) return;
      await _record(tx, AuditEventType.groupRemoved, actorUserId, userId, groupId, userGroupId);
      await _scheduleSync.afterGroupChange(tx, actorUserId, userId);
    });
    return members(groupId, mayView: mayView);
  }

  /// 404 when the group does not exist (or is deleted); otherwise whether it
  /// is active.
  Future<bool> _requireGroup(int groupId) async =>
      await _members.groupIsActive(groupId) ?? (throw ApiException.notFound('Group $groupId does not exist.'));

  /// The right to manage assignments in every company of each employee.
  Future<void> requireMayManage(List<int> userIds, Future<void> Function(int companyId) mayManage) async {
    final companies = await _members.companiesOf(userIds);
    for (final userId in userIds) {
      final ofUser = companies[userId] ?? const [];
      // Someone in no company is not an employee HR can manage here.
      if (ofUser.isEmpty) throw ApiException.notFound('Employee $userId does not exist.');
      for (final (companyId, _) in ofUser) {
        await mayManage(companyId);
      }
    }
  }

  Future<List<GroupMember>> _withDetails(List<GroupMemberRow> rows, Future<bool> Function(int companyId) mayView) async {
    final ids = [for (final row in rows) row.userId];
    final companies = await _members.companiesOf(ids);
    final groups = await _members.groupsOf(ids);
    final visible = <int, bool>{};
    Future<bool> visibleCompany(int companyId) async => visible[companyId] ??= await mayView(companyId);
    return [
      for (final row in rows)
        if (await _anyVisible(companies[row.userId] ?? const [], visibleCompany))
          GroupMember(
            id: row.userId,
            firstName: row.firstName,
            lastName: row.lastName,
            code: row.code,
            companies: [for (final (_, name) in companies[row.userId] ?? const <(int, String)>[]) name],
            companyIds: [for (final (id, _) in companies[row.userId] ?? const <(int, String)>[]) id],
            groups: groups[row.userId] ?? const [],
          ),
    ];
  }

  static Future<bool> _anyVisible(List<(int, String)> companies, Future<bool> Function(int) visible) async {
    for (final (companyId, _) in companies) {
      if (await visible(companyId)) return true;
    }
    return false;
  }

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, int userId, int groupId, int userGroupId) =>
      _audit.record(
        tx,
        AuditEvent(
          type: type,
          actorUserId: actorUserId,
          references: {
            EventLogReference.user: userId,
            EventLogReference.group: groupId,
            EventLogReference.userGroup: userGroupId,
          },
        ),
      );

  /// Adding and removing are idempotent, so a transaction MySQL rolls back
  /// as a deadlock victim is simply run again.
  Future<void> _retryOnDeadlock(Future<void> Function(SqlExecutor tx) body) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _transactions.transaction(body);
      } on DatabaseQueryException catch (e) {
        if (!e.isDeadlock || attempt == _deadlockAttempts) rethrow;
      }
    }
  }
}
