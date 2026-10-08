import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../companies/company_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../languages/user_language_repository.dart';
import '../languages/user_language_service.dart';
import 'employee_assignment_repository.dart';
import 'employee_repository.dart';

/// "Manage employee assignments" (Figma Admin/HR Employees 04–07). Always
/// within one company: the employee must belong to the company in the path.
///
/// Adds only. Removing an assignment deletes a junction row, which waits
/// for IT (ERD.md); the endpoints accept additions and leave existing
/// assignments untouched. Every addition is audited in the same
/// transaction.
///
/// **One company per employee** (MVP decision 2026-10-08): an employee who
/// belongs to a company cannot be added to another. Transfers wait for IT's
/// relationship lifecycle; existing memberships are never removed.
class EmployeeAssignmentService {
  EmployeeAssignmentService({
    required this._assignments,
    required this._employees,
    required this._companies,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._userLanguages,
    required this._languageChanges,
  });

  final EmployeeAssignmentRepository _assignments;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final UserLanguageRepository _userLanguages;
  final UserLanguageService _languageChanges;

  /// Largest number of ids one request may add.
  static const maxIds = 100;

  /// Attempts of an add transaction that MySQL picks as a deadlock victim.
  static const _deadlockAttempts = 3;

  // ── EMP-04 Companies ───────────────────────────────────────────────────

  /// Companies, with every company the employee does not belong to marked
  /// not assignable while they belong to one (one company per employee).
  Future<AssignmentOptions> companies(int companyId, int userId) async {
    await _requireMember(_executor, companyId, userId);
    final members = await _assignments.memberCompanyIds(_executor, userId);
    return AssignmentOptions(
      options: [
        for (final o in await _assignments.companyOptions(_executor, userId))
          o.isAssigned || members.isEmpty ? o : o.withAssignable(false),
      ],
    );
  }

  /// Adds [userId] to the company in [request]. It must be an active,
  /// non-MFD company (validation error on `ids` otherwise). Companies the
  /// employee already belongs to are skipped, never duplicated. A new
  /// company is refused (409 `employee_company_limit`) while the employee
  /// belongs to another: checked first, then again after taking the
  /// user-row lock, so concurrent requests cannot add a second one.
  ///
  /// [mayManage] answers whether the actor may manage employees of a target
  /// company: adding someone to a company needs authority there too, not
  /// only in the company in the path.
  Future<AssignmentOptions> addCompanies(
    int actorUserId,
    int companyId,
    int userId,
    AddAssignmentsRequest request, {
    required Future<void> Function(int targetCompanyId) mayManage,
  }) async {
    final ids = _checkedIds(request);
    await _requireMember(_executor, companyId, userId);
    final options = {for (final o in await _assignments.companyOptions(_executor, userId)) o.id: o};
    for (final id in ids) {
      final option = options[id];
      if (option == null || (!option.isActive && !option.isAssigned)) {
        throw const ApiException.validation(AddAssignmentsRequest.fieldIds, 'Choose active companies only.');
      }
    }
    final toAdd = [for (final id in ids) if (!options[id]!.isAssigned) id];
    if (toAdd.isEmpty) return companies(companyId, userId);
    _requireNoOtherCompany(toAdd, await _assignments.memberCompanyIds(_executor, userId));
    for (final target in toAdd) {
      await mayManage(target);
    }

    await _addTransaction((tx) async {
      await _lockEmployee(tx, userId);
      await _requireMember(tx, companyId, userId);
      _requireNoOtherCompany(toAdd, await _assignments.memberCompanyIds(tx, userId));
      for (final target in toAdd) {
        final userCompanyId = await _assignments.addCompany(tx, userId, target);
        if (userCompanyId == null) continue; // added meanwhile: nothing to do
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.companyAssigned,
            actorUserId: actorUserId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.company: target,
              EventLogReference.userCompany: userCompanyId,
            },
          ),
        );
      }
    });
    return companies(companyId, userId);
  }

  /// One company per employee: adding [toAdd] must not give the employee a
  /// second company besides [members].
  static void _requireNoOtherCompany(List<int> toAdd, List<int> members) {
    final companiesAfter = {...members, ...toAdd};
    if (companiesAfter.length > 1) {
      throw const ApiException(
        409,
        ApiErrorCode.employeeCompanyLimit,
        'An employee belongs to one company. Moving employees between companies is not available yet.',
      );
    }
  }

  // ── EMP-05 Groups ──────────────────────────────────────────────────────

  /// Groups are universal (IT, 2026-10-08): an employee's groups apply in all
  /// their companies. Group membership grants no company access; that stays
  /// with company membership and permissions.
  Future<AssignmentOptions> groups(int companyId, int userId) async {
    await _requireMember(_executor, companyId, userId);
    return AssignmentOptions(options: await _assignments.groupOptions(_executor, userId));
  }

  /// Adds the active, non-MFD groups in [request]; already assigned ones are
  /// skipped, never duplicated.
  Future<AssignmentOptions> addGroups(int actorUserId, int companyId, int userId, AddAssignmentsRequest request) async {
    final ids = _checkedIds(request);
    await _requireMember(_executor, companyId, userId);
    final options = {for (final o in await _assignments.groupOptions(_executor, userId)) o.id: o};
    for (final id in ids) {
      final option = options[id];
      if (option == null || (!option.isActive && !option.isAssigned)) {
        throw const ApiException.validation(AddAssignmentsRequest.fieldIds, 'Choose active groups only.');
      }
    }
    await _addTransaction((tx) async {
      await _lockEmployee(tx, userId);
      await _requireMember(tx, companyId, userId);
      for (final id in ids.where((id) => !options[id]!.isAssigned)) {
        final userGroupId = await _assignments.addGroup(tx, userId, id);
        if (userGroupId == null) continue;
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.groupAssigned,
            actorUserId: actorUserId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.group: id,
              EventLogReference.userGroup: userGroupId,
            },
          ),
        );
      }
    });
    return groups(companyId, userId);
  }

  // ── EMP-06 Preferred language ──────────────────────────────────────────

  /// Active languages (and the employee's, even if since deactivated). The
  /// employee has at most one.
  Future<AssignmentOptions> languages(int companyId, int userId) async {
    await _requireMember(_executor, companyId, userId);
    return AssignmentOptions(options: await _userLanguages.options(_executor, userId));
  }

  /// Replaces the employee's preferred language: a preference update,
  /// audited as `employee.language.changed`.
  Future<AssignmentOptions> setLanguage(int actorUserId, int companyId, int userId, SetLanguageRequest request) async {
    await _requireMember(_executor, companyId, userId);
    await _languageChanges.change(
      actorUserId: actorUserId,
      userId: userId,
      languageId: request.languageId,
      precondition: (tx) => _requireMember(tx, companyId, userId),
    );
    return languages(companyId, userId);
  }

  // ── EMP-07 Access (credential groups) ──────────────────────────────────

  /// Credential groups, each marked assignable only when [actorUserId] may
  /// grant it (see [addCredentialGroups]).
  Future<AssignmentOptions> credentialGroups(int actorUserId, int companyId, int userId) async {
    await _requireMember(_executor, companyId, userId);
    final held = await _assignments.heldCredentialGroupIds(_executor, actorUserId);
    return AssignmentOptions(
      options: [
        for (final o in await _assignments.credentialGroupOptions(_executor, userId))
          held.contains(o.id) ? o : o.withAssignable(false),
      ],
    );
  }

  /// Adds the active, non-MFD credential groups in [request]; already
  /// assigned ones are skipped, never duplicated.
  ///
  /// A credential group is user-wide (`tblUserCredGroup` has no company), so
  /// it takes effect in every company the employee belongs to. [mayManage]
  /// is therefore asked for each of them, not only the company in the path:
  /// an HR user of one company cannot change someone's access elsewhere.
  ///
  /// **No privilege escalation.** IT has not defined a hierarchy between
  /// credential groups (CLARIFY-10), and Jitan does not invent one (not from
  /// names, not from `credGroupLevel`). The only grant known to be safe is a
  /// group the actor holds themselves: the employee then gets nothing the
  /// actor lacks. Any other grant is refused (403) until IT defines the
  /// rules. This also stops anyone from raising their own access.
  Future<AssignmentOptions> addCredentialGroups(
    int actorUserId,
    int companyId,
    int userId,
    AddAssignmentsRequest request, {
    required Future<void> Function(int memberCompanyId) mayManage,
  }) async {
    final ids = _checkedIds(request);
    await _requireMember(_executor, companyId, userId);
    final options = {for (final o in await _assignments.credentialGroupOptions(_executor, userId)) o.id: o};
    for (final id in ids) {
      final option = options[id];
      if (option == null || (!option.isActive && !option.isAssigned)) {
        throw const ApiException.validation(AddAssignmentsRequest.fieldIds, 'Choose active credential groups only.');
      }
    }
    final toAdd = [for (final id in ids) if (!options[id]!.isAssigned) id];
    if (toAdd.isEmpty) return credentialGroups(actorUserId, companyId, userId);
    _requireHeldByActor(toAdd, await _assignments.heldCredentialGroupIds(_executor, actorUserId));
    for (final member in await _assignments.memberCompanyIds(_executor, userId)) {
      await mayManage(member);
    }

    await _addTransaction((tx) async {
      await _lockEmployee(tx, userId);
      _requireHeldByActor(toAdd, await _assignments.heldCredentialGroupIds(tx, actorUserId));
      await _requireMember(tx, companyId, userId);
      for (final id in toAdd) {
        final userCredGroupId = await _assignments.addCredentialGroup(tx, userId, id);
        if (userCredGroupId == null) continue;
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.credentialGroupAssigned,
            actorUserId: actorUserId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.credGroup: id,
              EventLogReference.userCredGroup: userCredGroupId,
            },
          ),
        );
      }
    });
    return credentialGroups(actorUserId, companyId, userId);
  }

  static void _requireHeldByActor(List<int> toAdd, Set<int> held) {
    if (!held.containsAll(toAdd)) {
      throw const ApiException.forbidden(
        'You can grant only credential groups you hold yourself until the permission rules are defined (CLARIFY-10).',
      );
    }
  }

  // ── Shared ─────────────────────────────────────────────────────────────

  /// The first statement of every assignment transaction: locks the
  /// employee's `tblUser` row, so changes to one employee run one after the
  /// other. Taken first, while the transaction holds no other lock, it cannot
  /// be part of a deadlock; and the plain reads that follow see the data as
  /// of after the wait (MySQL REPEATABLE READ takes the snapshot at the
  /// first plain read). Locking reads with joins are avoided on purpose:
  /// mysql_client_plus 0.1.3 drops the connection when a SELECT is answered
  /// with an error such as a deadlock (DB-DRIVER-01).
  Future<void> _lockEmployee(SqlExecutor tx, int userId) async {
    if (!await _employees.lockUser(tx, userId)) throw ApiException.notFound('Employee $userId does not exist.');
  }

  /// Runs an add transaction, retrying it when MySQL rolls it back as a
  /// deadlock victim (two concurrent adds of the same pair lock each other's
  /// gap). Safe because adding is idempotent: a pair that now exists is
  /// skipped and not audited again.
  Future<void> _addTransaction(Future<void> Function(SqlExecutor tx) body) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _transactions.transaction(body);
      } on DatabaseQueryException catch (e) {
        if (!e.isDeadlock || attempt == _deadlockAttempts) rethrow;
      }
    }
  }

  /// 404 unless the company exists (non-MFD) and [userId] is its member: an
  /// employee of another company reveals nothing.
  Future<void> _requireMember(SqlExecutor executor, int companyId, int userId) async {
    if (!await _companies.exists(companyId) || await _employees.findInCompany(executor, companyId, userId) == null) {
      throw ApiException.notFound('Employee $userId is not in company $companyId.');
    }
  }

  static List<int> _checkedIds(AddAssignmentsRequest request) {
    final ids = request.ids.toSet().toList();
    if (ids.isEmpty || ids.length > maxIds || ids.any((id) => id <= 0)) {
      throw const ApiException.validation(AddAssignmentsRequest.fieldIds, 'Choose at least one option.');
    }
    return ids;
  }
}
