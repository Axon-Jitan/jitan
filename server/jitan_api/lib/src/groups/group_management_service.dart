import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'group_management_repository.dart';

/// HR/Admin managing employee groups (backlog GRP-01). Groups are universal
/// across companies (IT, 2026-10-08). A name is required, at most 100
/// characters and unique ignoring upper/lower case (the ERD has no unique key,
/// so Jitan checks). A group with employees can't be deactivated, so nobody
/// silently loses their group or its schedule. Every change is audited in
/// the same transaction; an action that changes nothing is not.
class GroupManagementService {
  GroupManagementService({
    required this._groups,
    required this._audit,
    required this._transactions,
    required this._executor,
  });

  final GroupManagementRepository _groups;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;

  Future<List<GroupOverview>> overview() => _groups.overview(_executor);

  /// Adds the group [name] (from [validName]) inside the caller's
  /// transaction [tx], audited; its ID. Create group (GroupSetupService)
  /// adds its employees and work hours in the same transaction.
  Future<int> createIn(SqlExecutor tx, int actorUserId, String name) async {
    if (await _groups.nameTaken(tx, name)) throw _duplicate(name);
    final id = await _groups.insert(tx, name);
    await _record(tx, AuditEventType.groupCreated, actorUserId, id);
    return id;
  }

  Future<GroupOverview> rename(int actorUserId, int groupId, GroupNameRequest request) async {
    final name = validName(request.name);
    await _transactions.transaction((tx) async {
      final group = await _lock(tx, groupId);
      if (group.name == name) return;
      if (await _groups.nameTaken(tx, name, exceptGroupId: groupId)) throw _duplicate(name);
      await _groups.rename(tx, groupId, name);
      await _record(tx, AuditEventType.groupRenamed, actorUserId, groupId);
    });
    return find(groupId);
  }

  /// 409 `group_in_use` while employees are in the group.
  Future<GroupOverview> deactivate(int actorUserId, int groupId) async {
    await _transactions.transaction((tx) async {
      final group = await _lock(tx, groupId);
      if (!group.isActive) return;
      final employees = await _groups.employeeCount(tx, groupId);
      if (employees > 0) {
        throw ApiException(
          409,
          ApiErrorCode.groupInUse,
          'Move the $employees ${employees == 1 ? 'employee' : 'employees'} in ${group.name} to another group first.',
        );
      }
      await _groups.setActive(tx, groupId, active: false);
      await _record(tx, AuditEventType.groupDeactivated, actorUserId, groupId);
    });
    return find(groupId);
  }

  Future<GroupOverview> reactivate(int actorUserId, int groupId) async {
    await _transactions.transaction((tx) async {
      final group = await _lock(tx, groupId);
      if (group.isActive) return;
      await _groups.setActive(tx, groupId, active: true);
      await _record(tx, AuditEventType.groupReactivated, actorUserId, groupId);
    });
    return find(groupId);
  }

  Future<GroupOverview> _lock(SqlExecutor tx, int groupId) async =>
      await _groups.lock(tx, groupId) ?? (throw ApiException.notFound('Group $groupId does not exist.'));

  Future<GroupOverview> find(int groupId) async =>
      (await _groups.overview(_executor)).where((g) => g.id == groupId).firstOrNull ??
      (throw ApiException.notFound('Group $groupId does not exist.'));

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actorUserId, int groupId) => _audit.record(
        tx,
        AuditEvent(type: type, actorUserId: actorUserId, references: {EventLogReference.group: groupId}),
      );

  /// The trimmed name; 400 when empty or longer than the column.
  static String validName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) throw const ApiException.validation(GroupNameRequest.fieldName, 'Enter a name.');
    if (name.runes.length > GroupNameRequest.maxNameLength) {
      throw const ApiException.validation(
        GroupNameRequest.fieldName,
        'The name can be at most ${GroupNameRequest.maxNameLength} characters.',
      );
    }
    return name;
  }

  static ApiException _duplicate(String name) => ApiException(
        409,
        ApiErrorCode.duplicateGroupName,
        'A group named "$name" already exists.',
        field: GroupNameRequest.fieldName,
      );
}
