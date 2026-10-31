import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import 'credential_repository.dart';
import 'password_hasher.dart';
import 'password_policy.dart';

/// How setting the first password ended.
enum FirstPasswordResult {
  set,

  /// No active employee has this code.
  noSuchEmployee,

  /// More than one employee has this code: nothing is guessed.
  ambiguousCode,

  /// This account has a password: the tool can't take over an account.
  alreadyHasPassword,
}

/// Lets IT give the very first person a password on a fresh database, where
/// nobody can generate an onboarding QR yet (AUTH-03). Only for someone with
/// no password, and audited. The person is onboarded by it: "onboarding
/// complete" is exactly `userPassword IS NOT NULL`.
class FirstPasswordService {
  const FirstPasswordService({
    required this._transactions,
    required this._hasher,
    this._credentials = const CredentialRepository(),
    this._audit = const AuditLogRepository(),
  });

  final TransactionRunner _transactions;
  final PasswordHasher _hasher;
  final CredentialRepository _credentials;
  final AuditLogRepository _audit;

  /// Throws `ApiException` when [password] breaks the password rules.
  Future<FirstPasswordResult> set(String code, String password) async {
    PasswordPolicy.check(password);
    final hash = await _hasher.hash(password);
    return _transactions.transaction((tx) async {
      final users = await _credentials.activeByCode(tx, code);
      if (users.isEmpty) return FirstPasswordResult.noSuchEmployee;
      if (users.length > 1) return FirstPasswordResult.ambiguousCode;
      final userId = users.single;
      if (!await _credentials.setPasswordAfterReset(tx, userId, hash)) return FirstPasswordResult.alreadyHasPassword;
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.firstPasswordSet,
          actorUserId: userId,
          references: {EventLogReference.user: userId},
        ),
      );
      return FirstPasswordResult.set;
    });
  }
}
