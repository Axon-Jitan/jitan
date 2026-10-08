import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../companies/company_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'employee_assignment_repository.dart';
import 'employee_repository.dart';

/// "Manage employee assignments" (Figma Admin/HR Employees 04–07). Always
/// within one company: the employee must belong to the company in the path.
///
/// Adds only. Removing an assignment deletes a junction row, which waits
/// for IT (ERD.md); the endpoints accept additions and leave existing
/// assignments untouched. Every addition is audited in the same
/// transaction.
class EmployeeAssignmentService {
  EmployeeAssignmentService({
    required this._assignments,
    required this._employees,
    required this._companies,
    required this._audit,
    required this._transactions,
    required this._executor,
  });

  final EmployeeAssignmentRepository _assignments;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;

  /// Largest number of ids one request may add.
  static const maxIds = 100;

  // ── EMP-04 Companies ───────────────────────────────────────────────────

  Future<AssignmentOptions> companies(int companyId, int userId) async {
    await _requireMember(_executor, companyId, userId);
    return AssignmentOptions(options: await _assignments.companyOptions(_executor, userId));
  }

  /// Adds [userId] to each company in [request]. Each must be an active,
  /// non-MFD company (validation error on `ids` otherwise). Companies the
  /// employee already belongs to are skipped, never duplicated.
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
    for (final target in toAdd) {
      await mayManage(target);
    }

    await _transactions.transaction((tx) async {
      await _requireMember(tx, companyId, userId);
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

  // ── Shared ─────────────────────────────────────────────────────────────

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
