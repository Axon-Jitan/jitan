import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/credential_repository.dart';
import '../companies/company_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../groups/group_repository.dart';
import '../http/api_exception.dart';
import 'employee_repository.dart';
import 'personal_qr_code.dart';

/// Employee use cases. Everything is scoped to one company.
class EmployeeService {
  EmployeeService({
    required this._employees,
    required this._companies,
    required this._groups,
    required this._audit,
    required this._transactions,
    this._credentials = const CredentialRepository(),
    this._personalQrCode = newPersonalQrCode,
  });

  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final GroupRepository _groups;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final CredentialRepository _credentials;
  final String Function() _personalQrCode;

  /// Longest accepted search text. Longer input is rejected, not truncated.
  static const maxSearchLength = 100;

  /// Employees of [companyId], optionally filtered by name or code.
  /// 404 when the company does not exist or is marked for deletion.
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? search}) async {
    final term = search?.trim() ?? '';
    if (term.length > maxSearchLength) {
      throw const ApiException.badRequest('Search text must be at most $maxSearchLength characters.');
    }
    await _requireCompany(companyId);
    return _employees.listForCompany(companyId, nameOrCodeContains: term.isEmpty ? null : term);
  }

  /// One employee of [companyId]. 404 when the company does not exist or
  /// the user is not a (non-deleted) member of it, so an ID from another
  /// company reveals nothing.
  Future<EmployeeDetails> details(int companyId, int userId) async {
    await _requireCompany(companyId);
    return await _employees.findDetails(companyId, userId) ??
        (throw ApiException.notFound('Employee $userId is not in company $companyId.'));
  }

  /// HR/Admin "Reset account access" for an employee who is locked out.
  ///
  /// Clears `tblUser.userPassword` in one audited transaction. Effects:
  /// every session of the employee ends at once (sessions are bound to the
  /// password hash, GAP-05); the existing `userQRcode` is unchanged and, with
  /// no password set, starts account setup again; the employee sets a new
  /// password, which blocks the QR again. Employees cannot reset themselves.
  ///
  /// 404 outside [companyId]; 409 `account_not_activated` when the employee
  /// never set a password (nothing to reset).
  Future<void> resetAccess(int actorUserId, int companyId, int userId) async {
    if (actorUserId == userId) {
      throw const ApiException.forbidden('You can’t reset your own account access.');
    }
    await _requireCompany(companyId);
    await _transactions.transaction((tx) async {
      if (await _employees.findInCompany(tx, companyId, userId) == null) {
        throw ApiException.notFound('Employee $userId is not in company $companyId.');
      }
      if (!await _credentials.clearPassword(tx, userId)) {
        throw const ApiException(
          409,
          ApiErrorCode.accountNotActivated,
          'This employee hasn’t set up Jitan yet, so there is no access to reset.',
        );
      }
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.accountAccessReset,
          actorUserId: actorUserId,
          references: {EventLogReference.user: userId, EventLogReference.company: companyId},
        ),
      );
    });
  }

  /// The QR [userId] scans to onboard, which is also their permanent personal
  /// QR for Jitan Terminal: `tblUser.userQRcode` (IT decision, 2026-10-07).
  ///
  /// Returns the stored value. If the employee has none (e.g. created outside
  /// Jitan), a new unguessable one is stored first, once, and audited; it is
  /// never derived from the userID or employee code, and an existing value is
  /// never replaced.
  ///
  /// 404 when the company does not exist or the user is not its member.
  Future<String> onboardingQr(int actorUserId, int companyId, int userId) async {
    await _requireCompany(companyId);
    return _transactions.transaction((tx) async {
      final current = await _employees.personalQrCode(tx, companyId, userId);
      if (!current.isMember) throw ApiException.notFound('Employee $userId is not in company $companyId.');
      if (current.qrCode != null) return current.qrCode!;

      final generated = _personalQrCode();
      if (await _employees.setPersonalQrCodeIfMissing(tx, userId, generated)) {
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.personalQrGenerated,
            actorUserId: actorUserId,
            references: {EventLogReference.user: userId, EventLogReference.company: companyId},
          ),
        );
        return generated;
      }
      // Another request stored one first: use theirs.
      return (await _employees.personalQrCode(tx, companyId, userId)).qrCode ??
          (throw StateError('Personal QR for user $userId is still missing after an update.'));
    });
  }

  /// Creates an employee in [companyId] on behalf of [actorUserId].
  ///
  /// In one transaction: the `tblUser` row (active, with a new personal QR),
  /// its `tblUserCompany` link, the optional `tblUserGroup` link, and the
  /// `tblEventLog` entry. Any failure rolls all of it back.
  ///
  /// - 400 `validation_failed` (with `field`) for missing names or code, or an
  ///   unknown/inactive group
  /// - 404 when the company does not exist
  /// - 409 `duplicate_employee_code` when the code is taken
  Future<EmployeeSummary> create(int actorUserId, int companyId, CreateEmployeeRequest request) async {
    final firstName = _required(request.firstName, CreateEmployeeRequest.fieldFirstName, 'First name');
    final lastName = _required(request.lastName, CreateEmployeeRequest.fieldLastName, 'Last name');
    final code = _required(request.code, CreateEmployeeRequest.fieldCode, 'Employee code');
    final phone = _optional(request.phone);
    final groupId = request.groupId;

    await _requireCompany(companyId);
    if (groupId != null && !await _groups.isAssignable(groupId)) {
      throw const ApiException.validation(CreateEmployeeRequest.fieldGroupId, 'Choose an existing, active group.');
    }

    try {
      return await _transactions.transaction((tx) async {
        if (await _employees.codeExists(tx, code)) throw _duplicateCode(code);

        final userId = await _employees.insertUser(
          tx,
          firstName: firstName,
          lastName: lastName,
          code: code,
          personalQrCode: _personalQrCode(),
          phone: phone,
        );
        final userCompanyId = await _employees.addToCompany(tx, userId, companyId);
        final userGroupId = groupId == null ? null : await _employees.addToGroup(tx, userId, groupId);

        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.employeeCreated,
            actorUserId: actorUserId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.company: companyId,
              EventLogReference.userCompany: userCompanyId,
              EventLogReference.group: ?groupId,
              EventLogReference.userGroup: ?userGroupId,
            },
          ),
        );

        return await _employees.findInCompany(tx, companyId, userId) ??
            (throw StateError('Created user $userId is not readable in company $companyId.'));
      });
    } on DatabaseQueryException catch (e) {
      // Another request may take the code between the check and the insert.
      if (e.isDuplicateKey) throw _duplicateCode(code);
      if (e.isValueTooLong) throw const ApiException.badRequest('A value is longer than allowed.');
      rethrow;
    }
  }

  Future<void> _requireCompany(int companyId) async {
    if (!await _companies.exists(companyId)) {
      throw ApiException.notFound('Company $companyId does not exist.');
    }
  }

  static String _required(String value, String field, String label) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ApiException.validation(field, '$label is required.');
    return trimmed;
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static ApiException _duplicateCode(String code) => ApiException(
        409,
        ApiErrorCode.duplicateEmployeeCode,
        'Employee code "$code" is already in use.',
        field: CreateEmployeeRequest.fieldCode,
      );
}
