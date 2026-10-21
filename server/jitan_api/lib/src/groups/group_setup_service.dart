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
/// Employees and work hours are optional (product owner, 2026-10-21). The
/// ERD as it is keeps a group's hours on the employees whose only group it
/// is, so hours then need at least one chosen employee in no other group.
/// With [_groupsOwnSchedules] (PROPOSAL, ERD_GAPS GAP-15, local database
/// only) the group keeps its hours itself, so that check goes.
class GroupSetupService {
  GroupSetupService({
    required this._management,
    required this._members,
    required this._schedules,
    required this._transactions,
    this._groupsOwnSchedules = false,
  });

  final GroupManagementService _management;
  final GroupMemberService _members;
  final ScheduleEditingService _schedules;
  final TransactionRunner _transactions;
  final bool _groupsOwnSchedules;

  /// [mayManage] checks the right to change the assignments of an employee
  /// in one of their companies (needed in every company of each employee).
  Future<GroupOverview> create(
    int actorUserId,
    CreateGroupRequest request, {
    required Future<void> Function(int companyId) mayManage,
  }) async {
    // Everything that can be checked is checked before writing anything.
    final name = GroupManagementService.validName(request.name);
    final ids = request.employeeIds.isEmpty
        ? const <int>[]
        : GroupMemberService.validIds(request.employeeIds, CreateGroupRequest.fieldEmployeeIds);
    final hours = request.schedule;
    final schedule = hours == null ? null : await _schedules.prepareSchedule(hours);
    await _members.requireMayManage(ids, mayManage);
    if (schedule != null && !_groupsOwnSchedules) {
      final groups = await _members.groupsOf(ids);
      if (!ids.any((id) => (groups[id] ?? const []).isEmpty)) {
        throw const ApiException.validation(
          CreateGroupRequest.fieldEmployeeIds,
          'Work hours need an employee who is in no other group: they are kept on them.',
        );
      }
    }
    final id = await _transactions.transaction((tx) async {
      final id = await _management.createIn(tx, actorUserId, name);
      if (ids.isNotEmpty) await _members.addIn(tx, actorUserId, id, ids);
      if (schedule != null) await _schedules.applySchedule(tx, actorUserId, id, schedule);
      return id;
    });
    return _management.find(id);
  }
}
