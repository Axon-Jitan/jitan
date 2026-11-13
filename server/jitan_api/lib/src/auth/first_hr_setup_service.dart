import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../employees/employee_assignment_repository.dart';
import '../employees/employee_repository.dart';
import '../employees/personal_qr_code.dart';
import '../http/api_exception.dart';
import 'credential_repository.dart';
import 'first_hr_repository.dart';
import 'password_hasher.dart';
import 'password_policy.dart';

/// Whom an employee code belongs to, before anything is changed.
enum FirstHrCode {
  /// Nobody: the person is added.
  newEmployee,

  /// An active employee without a password: the person is set up.
  existing,

  /// More than one active employee: nothing is guessed.
  ambiguous,

  /// The account already has a password: the tool can't take it over.
  hasPassword,

  /// A switched-off or removed employee has it: codes are never reused.
  taken,
}

/// How setting up ended.
enum FirstHrResult {
  done,
  ambiguousCode,
  alreadyHasPassword,
  codeTaken,

  /// The access group is gone or switched off.
  unknownGroup,

  /// The group opens no module yet, and none was chosen.
  moduleNeeded,
}

/// The very first HR person, in one step (AUTH-03, user 2026-11-13): IT runs
/// `jitan-first-hr` on its server, with the person beside it. In one
/// transaction: the employee (added when the code is new, with a Terminal QR
/// as at any employee creation), their access group, the group's module when
/// it opens none yet, and the password they type. Every step is audited, the
/// person as actor; any failure leaves nothing changed.
///
/// IT still decides who gets access (V1): the groups and modules are IT's
/// rows, chosen by IT at its own server.
class FirstHrSetupService {
  FirstHrSetupService({
    required this._transactions,
    required this._executor,
    required this._hasher,
    this._repository = const FirstHrRepository(),
    this._credentials = const CredentialRepository(),
    this._assignments = const EmployeeAssignmentRepository(),
    this._audit = const AuditLogRepository(),
    String Function()? personalQrCode,
  }) : _personalQrCode = personalQrCode ?? newPersonalQrCode;

  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final PasswordHasher _hasher;
  final FirstHrRepository _repository;
  final CredentialRepository _credentials;
  final EmployeeAssignmentRepository _assignments;
  final AuditLogRepository _audit;
  final String Function() _personalQrCode;

  /// Whom [code] belongs to, and their name when it is someone.
  Future<({FirstHrCode code, String? name})> lookUp(String code) => _lookUp(_executor, code.trim());

  Future<List<AccessOption>> accessGroups() => _repository.accessGroups(_executor);

  Future<List<AccessOption>> modules() => _repository.modules(_executor);

  Future<bool> opensAModule(int credGroupId) => _repository.opensAModule(_executor, credGroupId);

  /// Sets the person up. [firstName] and [lastName] are needed only for a new
  /// code; [moduleId] only when the group opens no module yet. Throws
  /// `ApiException` for a password or a name the rules refuse.
  Future<FirstHrResult> setUp({
    required String code,
    String? firstName,
    String? lastName,
    required int credGroupId,
    int? moduleId,
    required String password,
  }) async {
    code = code.trim();
    if (code.isEmpty || code.length > CreateEmployeeRequest.maxCodeLength) {
      throw const ApiException.validation('code', 'Use an employee code of 1 to ${CreateEmployeeRequest.maxCodeLength} characters.');
    }
    PasswordPolicy.check(password);
    final hash = await _hasher.hash(password);

    // A result other than `done` throws inside, so the transaction rolls
    // back whatever it already did (a new employee, a module link).
    try {
      return await _transactions.transaction((tx) => _setUp(tx, code, firstName, lastName, credGroupId, moduleId, hash));
    } on _Stopped catch (stopped) {
      return stopped.result;
    }
  }

  Future<FirstHrResult> _setUp(SqlExecutor tx, String code, String? firstName, String? lastName, int credGroupId, int? moduleId, String hash) async {
    final found = await _lookUp(tx, code);
    final int userId;
    switch (found.code) {
      case FirstHrCode.ambiguous:
        throw const _Stopped(FirstHrResult.ambiguousCode);
      case FirstHrCode.hasPassword:
        throw const _Stopped(FirstHrResult.alreadyHasPassword);
      case FirstHrCode.taken:
        throw const _Stopped(FirstHrResult.codeTaken);
      case FirstHrCode.existing:
        userId = (await _credentials.activeByCode(tx, code)).single;
      case FirstHrCode.newEmployee:
        final first = _name('firstName', firstName, CreateEmployeeRequest.maxFirstNameLength);
        final last = _name('lastName', lastName, CreateEmployeeRequest.maxLastNameLength);
        userId = await EmployeeRepository(tx).insertUser(tx, firstName: first, lastName: last, code: code, personalQrCode: _personalQrCode(), phone: null);
        await _record(tx, AuditEventType.employeeCreated, userId, {EventLogReference.user: userId});
    }

    if (!(await _repository.accessGroups(tx)).any((g) => g.id == credGroupId)) throw const _Stopped(FirstHrResult.unknownGroup);
    if (!await _repository.opensAModule(tx, credGroupId)) {
      if (moduleId == null || !(await _repository.modules(tx)).any((m) => m.id == moduleId)) {
        throw const _Stopped(FirstHrResult.moduleNeeded);
      }
      await _repository.linkModule(tx, credGroupId, moduleId);
      await _record(tx, AuditEventType.credentialGroupModuleLinked, userId, {EventLogReference.credGroup: credGroupId});
    }

    final userCredGroupId = await _assignments.addCredentialGroup(tx, userId, credGroupId);
    if (userCredGroupId != null) {
      await _record(tx, AuditEventType.credentialGroupAssigned, userId, {
        EventLogReference.user: userId,
        EventLogReference.credGroup: credGroupId,
        EventLogReference.userCredGroup: userCredGroupId,
      });
    }

    if (!await _credentials.setPasswordAfterReset(tx, userId, hash)) throw const _Stopped(FirstHrResult.alreadyHasPassword);
    await _record(tx, AuditEventType.firstPasswordSet, userId, {EventLogReference.user: userId});
    return FirstHrResult.done;
  }

  Future<({FirstHrCode code, String? name})> _lookUp(SqlExecutor executor, String code) async {
    final active = await _credentials.activeByCode(executor, code);
    if (active.length > 1) return (code: FirstHrCode.ambiguous, name: null);
    if (active.length == 1) {
      final name = await _repository.nameOf(executor, active.single);
      final hasPassword = await _repository.hasPassword(executor, active.single);
      return (code: hasPassword ? FirstHrCode.hasPassword : FirstHrCode.existing, name: name);
    }
    if (await EmployeeRepository(executor).codeExists(executor, code)) return (code: FirstHrCode.taken, name: null);
    return (code: FirstHrCode.newEmployee, name: null);
  }

  static String _name(String field, String? value, int max) {
    final name = value?.trim() ?? '';
    if (name.isEmpty || name.length > max) throw ApiException.validation(field, 'Use 1 to $max characters.');
    return name;
  }

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actor, Map<EventLogReference, int> references) =>
      _audit.record(tx, AuditEvent(type: type, actorUserId: actor, references: references));
}

/// Ends the transaction with a result, rolling it back.
class _Stopped implements Exception {
  const _Stopped(this.result);

  final FirstHrResult result;
}
