import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/credential_repository.dart';
import '../auth/password_hasher.dart';
import '../auth/password_policy.dart';
import '../auth/request_identity.dart';
import '../auth/session_tokens.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'user_repository.dart';

/// What a signed-in employee does with their own account.
class AccountService {
  AccountService({
    required this._credentials,
    required this._users,
    required this._audit,
    required this._transactions,
    required this._sessions,
    this._hasher = const PasswordHasher(),
  });

  final CredentialRepository _credentials;
  final UserRepository _users;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SessionTokens _sessions;
  final PasswordHasher _hasher;

  /// Profile → Password & web login → Change password.
  ///
  /// The session proves who the employee is; the current password is not
  /// asked, so someone who forgot it but is still signed in on a trusted
  /// device can set a new one without HR/Admin. The new Argon2id hash
  /// replaces the old one in one audited transaction. Every other session
  /// ends (their password fingerprint no longer matches); this device gets a
  /// new session and stays signed in.
  Future<SessionResponse> changePassword(RequestIdentity identity, ChangePasswordRequest request) async {
    final deviceId = identity.deviceId ??
        (throw const ApiException.forbidden('Changing the password needs a signed-in device.'));
    PasswordPolicy.check(request.newPassword, field: ChangePasswordRequest.fieldNewPassword);
    final hash = await _hasher.hash(request.newPassword);

    await _transactions.transaction((tx) async {
      if (!await _credentials.replacePassword(tx, identity.userId, hash)) {
        throw const ApiException.unauthenticated('The session is not valid. Sign in again.');
      }
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.passwordChanged,
          actorUserId: identity.userId,
          references: {EventLogReference.user: identity.userId},
        ),
      );
    });

    final account = await _users.account(identity.userId) ??
        (throw const ApiException.unauthenticated('The session is not valid. Sign in again.'));
    final session = _sessions.issue(userId: identity.userId, deviceId: deviceId, passwordHash: hash);
    return SessionResponse(
      account: account,
      session: SessionInfo(accessToken: session.token, expiresAt: session.expiresAt),
    );
  }
}
