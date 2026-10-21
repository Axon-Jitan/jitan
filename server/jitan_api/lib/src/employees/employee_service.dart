import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/credential_repository.dart';
import '../companies/company_repository.dart';
import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import '../groups/group_repository.dart';
import '../http/api_exception.dart';
import '../onboarding/account_setup_rules.dart';
import '../onboarding/onboarding_repository.dart';
import 'employee_repository.dart';
import '../schedules/employee_schedule_sync.dart';
import '../temporary_qr/temporary_qr_service.dart';
import 'personal_qr_code.dart';

/// Employee use cases. Everything is scoped to one company.
class EmployeeService {
  EmployeeService({
    required this._employees,
    required this._companies,
    required this._groups,
    required this._audit,
    required this._transactions,
    required this._temporaryQr,
    this._accounts = const OnboardingRepository(),
    this._credentials = const CredentialRepository(),
    this._personalQrCode = newPersonalQrCode,
    required this._scheduleSync,
  });

  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final GroupRepository _groups;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final TemporaryQrService _temporaryQr;
  final OnboardingRepository _accounts;
  final CredentialRepository _credentials;
  final String Function() _personalQrCode;
  final EmployeeScheduleSync _scheduleSync;

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
    final details = await _employees.findDetails(companyId, userId) ??
        (throw ApiException.notFound('Employee $userId is not in company $companyId.'));
    if (details.isActivated) return details;
    final state = await _transactions.transaction((tx) => _setupState(tx, userId));
    return details.copyWith(accessResetPending: state == AccountSetupState.resetPending);
  }

  Future<AccountSetupState?> _setupState(SqlExecutor executor, int userId) async {
    final user = await _accounts.findById(executor, userId);
    return user == null ? null : AccountSetupRules.stateOf(_accounts, executor, user);
  }

  /// HR/Admin "Reset account access" for an employee who is locked out.
  ///
  /// Clears `tblUser.userPassword` in one audited transaction. Effects:
  /// every session of the employee ends at once (sessions are bound to the
  /// password hash, GAP-05); HR/Admin can then generate a temporary recovery
  /// QR ([temporaryQr]) with which the employee sets a new password. The
  /// Terminal QR (`userQRcode`) is unchanged. Employees cannot reset
  /// themselves.
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

  /// A temporary QR for [userId] (IT decision 2026-10-08): onboarding for an
  /// employee who has not set up Jitan, recovery after "Reset account
  /// access". Valid 10 minutes, single use; generating one invalidates the
  /// previous one of the same purpose. Never stored in MySQL; the fact that
  /// it was generated is audited (before it exists, so none is unaudited).
  ///
  /// 404 outside [companyId]; 409 `account_inactive` for a disabled employee;
  /// 409 `onboarding_already_completed` (onboarding) or `account_not_reset`
  /// (recovery) while a password is set.
  Future<TemporaryQrResponse> temporaryQr(int actorUserId, int companyId, int userId, TemporaryQrPurpose purpose) async {
    await _requireCompany(companyId);
    await _transactions.transaction((tx) async {
      final employee = await _employees.findInCompany(tx, companyId, userId) ??
          (throw ApiException.notFound('Employee $userId is not in company $companyId.'));
      if (!employee.isActive) {
        throw const ApiException(409, ApiErrorCode.accountInactive, 'This employee is not active.');
      }
      final state = employee.isActivated ? AccountSetupState.activated : await _setupState(tx, userId);
      // Onboarding only for an account that never had a password; recovery
      // only after Reset account access (the HR-authorized recovery).
      if (purpose == TemporaryQrPurpose.onboarding && state == AccountSetupState.resetPending) {
        throw const ApiException(
          409,
          ApiErrorCode.onboardingAlreadyCompleted,
          'This employee’s access was reset: generate a recovery QR instead.',
        );
      }
      if (purpose == TemporaryQrPurpose.recovery && state != AccountSetupState.resetPending && !employee.isActivated) {
        throw AccountSetupRules.notReset();
      }
      if (state == AccountSetupState.unexplained) {
        throw const ApiException.configurationError(
          'This account has no password but no pending reset. Reset account access is needed (check with IT).',
        );
      }
      if (employee.isActivated) {
        throw switch (purpose) {
          TemporaryQrPurpose.onboarding => const ApiException(
            409,
            ApiErrorCode.onboardingAlreadyCompleted,
            'This employee has already set up Jitan.',
          ),
          TemporaryQrPurpose.recovery => const ApiException(
            409,
            ApiErrorCode.accountNotReset,
            'Reset account access before generating a recovery QR.',
          ),
        };
      }
      await _audit.record(
        tx,
        AuditEvent(
          type: switch (purpose) {
            TemporaryQrPurpose.onboarding => AuditEventType.onboardingQrGenerated,
            TemporaryQrPurpose.recovery => AuditEventType.recoveryQrGenerated,
          },
          actorUserId: actorUserId,
          references: {EventLogReference.user: userId, EventLogReference.company: companyId},
        ),
      );
    });
    final issued = await _temporaryQr.issue(userId, purpose);
    return TemporaryQrResponse(qrCode: issued.token, purpose: purpose, expiresAt: issued.claims.expiresAt);
  }

  /// Creates an employee in [companyId] on behalf of [actorUserId].
  ///
  /// In one transaction (Add employee, Figma `153:970` → `985:2`): the
  /// `tblUser` row (active, with a new personal QR), its `tblUserCompany`
  /// links ([companyId] and the other chosen companies), its `tblUserGroup`
  /// links, its work hours (its group's; with several groups, those of
  /// `scheduleGroupId`), and their `tblEventLog` entries. Any failure rolls
  /// all of it back.
  ///
  /// - 400 `validation_failed` (with `field`) for missing names or code, a
  ///   value longer than its `tblUser` column, a malformed email, an unknown
  ///   company, an unknown/inactive group, or a schedule group the employee
  ///   is not in
  /// - 404 when the company does not exist
  /// - 409 `duplicate_employee_code` when the code is taken
  Future<EmployeeSummary> create(int actorUserId, int companyId, CreateEmployeeRequest request) async {
    final firstName = _required(
      request.firstName,
      CreateEmployeeRequest.fieldFirstName,
      'First name',
      CreateEmployeeRequest.maxFirstNameLength,
    );
    final lastName = _required(
      request.lastName,
      CreateEmployeeRequest.fieldLastName,
      'Last name',
      CreateEmployeeRequest.maxLastNameLength,
    );
    final code = _required(request.code, CreateEmployeeRequest.fieldCode, 'Employee code', CreateEmployeeRequest.maxCodeLength);
    final phone = _optional(request.phone, CreateEmployeeRequest.fieldPhone, 'Phone number', CreateEmployeeRequest.maxPhoneLength);
    final email = _optional(request.email, CreateEmployeeRequest.fieldEmail, 'Email', CreateEmployeeRequest.maxEmailLength);
    if (email != null && !_emailShape.hasMatch(email)) {
      throw const ApiException.validation(CreateEmployeeRequest.fieldEmail, 'Enter an email address like name@example.com.');
    }
    final otherCompanies = ({...request.companyIds}..remove(companyId)).toList()..sort();
    final groupIds = request.groupIds.toSet().toList()..sort();
    final scheduleGroupId = request.scheduleGroupId;

    await _requireCompany(companyId);
    for (final other in otherCompanies) {
      if (!await _companies.exists(other)) {
        throw const ApiException.validation(CreateEmployeeRequest.fieldCompanyIds, 'Choose existing companies.');
      }
    }
    for (final groupId in groupIds) {
      if (!await _groups.isAssignable(groupId)) {
        throw const ApiException.validation(CreateEmployeeRequest.fieldGroupIds, 'Choose existing, active groups.');
      }
    }
    if (scheduleGroupId != null && !groupIds.contains(scheduleGroupId)) {
      throw const ApiException.validation(
        CreateEmployeeRequest.fieldScheduleGroupId,
        'Choose the work schedule of one of the employee\'s groups.',
      );
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
          email: email,
        );
        final userCompanyId = await _employees.addToCompany(tx, userId, companyId);
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.employeeCreated,
            actorUserId: actorUserId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.company: companyId,
              EventLogReference.userCompany: userCompanyId,
            },
          ),
        );
        for (final other in otherCompanies) {
          final link = await _employees.addToCompany(tx, userId, other);
          await _audit.record(
            tx,
            AuditEvent(
              type: AuditEventType.companyAssigned,
              actorUserId: actorUserId,
              references: {
                EventLogReference.user: userId,
                EventLogReference.company: other,
                EventLogReference.userCompany: link,
              },
            ),
          );
        }
        for (final groupId in groupIds) {
          final link = await _employees.addToGroup(tx, userId, groupId);
          await _audit.record(
            tx,
            AuditEvent(
              type: AuditEventType.groupAssigned,
              actorUserId: actorUserId,
              references: {EventLogReference.user: userId, EventLogReference.group: groupId, EventLogReference.userGroup: link},
            ),
          );
        }
        // The employee gets their group's hours; with several groups, those
        // of the group HR chose as "Work schedule".
        if (groupIds.isNotEmpty) await _scheduleSync.afterGroupChange(tx, actorUserId, userId);
        if (scheduleGroupId != null && groupIds.length > 1) {
          await _scheduleSync.useGroup(tx, actorUserId, userId, scheduleGroupId);
        }

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

  /// Something@something.something, without spaces: catches typing
  /// mistakes; the address is never used to sign in.
  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _requireCompany(int companyId) async {
    if (!await _companies.exists(companyId)) {
      throw ApiException.notFound('Company $companyId does not exist.');
    }
  }

  static String _required(String value, String field, String label, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ApiException.validation(field, '$label is required.');
    return _fitting(trimmed, field, label, maxLength);
  }

  static String? _optional(String? value, String field, String label, int maxLength) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : _fitting(trimmed, field, label, maxLength);
  }

  /// Rejects a value longer than its column (characters as MySQL counts
  /// them), so the insert never fails with error 1406.
  static String _fitting(String value, String field, String label, int maxLength) {
    if (value.runes.length > maxLength) {
      throw ApiException.validation(field, '$label must be at most $maxLength characters.');
    }
    return value;
  }

  static ApiException _duplicateCode(String code) => ApiException(
        409,
        ApiErrorCode.duplicateEmployeeCode,
        'Employee code "$code" is already in use.',
        field: CreateEmployeeRequest.fieldCode,
      );
}
