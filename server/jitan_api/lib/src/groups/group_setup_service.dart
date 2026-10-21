import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../schedules/schedule_editing_service.dart';
import 'group_management_service.dart';
import 'group_member_service.dart';

/// Create group (Figma `HR / Employee groups — Create group`, steps 1–3):
/// the group, its employees from every company and its work hours and
/// break, written in **one** transaction, so a refusal anywhere leaves no
/// half-made group behind.
///
/// Every group has work hours (product owner, 2026-10-21). The ERD keeps a
/// group's hours on the employees whose only group it is, so at least one
/// chosen employee must be in no other group.
class GroupSetupService {
  GroupSetupService({
    required this._management,
    required this._members,
    required this._schedules,
    required this._transactions,
  });

  final GroupManagementService _management;
  final GroupMemberService _members;
  final ScheduleEditingService _schedules;
  final TransactionRunner _transactions;

  /// [mayManage] checks the right to change the assignments of an employee
  /// in one of their companies (needed in every company of each employee).
  Future<GroupOverview> create(
    int actorUserId,
    CreateGroupRequest request, {
    required Future<void> Function(int companyId) mayManage,
  }) async {
    // Everything that can be checked is checked before writing anything.
    final name = GroupManagementService.validName(request.name);
    final ids = GroupMemberService.validIds(request.employeeIds, CreateGroupRequest.fieldEmployeeIds);
    final schedule = await _schedules.prepareSchedule(request.schedule);
    await _members.requireMayManage(ids, mayManage);
    final groups = await _members.groupsOf(ids);
    if (!ids.any((id) => (groups[id] ?? const []).isEmpty)) {
      throw const ApiException.validation(
        CreateGroupRequest.fieldEmployeeIds,
        'Choose at least one employee who is in no other group: the work hours are kept on them.',
      );
    }
    final id = await _transactions.transaction((tx) async {
      final id = await _management.createIn(tx, actorUserId, name);
      await _members.addIn(tx, actorUserId, id, ids);
      await _schedules.applySchedule(tx, actorUserId, id, schedule);
      return id;
    });
    return _management.find(id);
  }
}
