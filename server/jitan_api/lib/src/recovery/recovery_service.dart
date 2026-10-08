import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/credential_repository.dart';
import '../auth/device_id.dart';
import '../auth/password_hasher.dart';
import '../auth/password_policy.dart';
import '../auth/session_tokens.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../onboarding/account_setup_rules.dart';
import '../onboarding/onboarding_repository.dart';
import '../temporary_qr/temporary_qr_service.dart';
import '../temporary_qr/temporary_qr_tokens.dart';

/// Password recovery with a **temporary recovery QR** (IT decision
/// 2026-10-08), after HR/Admin "Reset account access" cleared the password
/// and ended every session. The employee scans the QR, sets a new password
/// and is signed in. The permanent Terminal QR never recovers an account.
///
/// - The QR must be valid, unexpired, current, unused and for recovery.
/// - The account must be in the reset state (`userPassword IS NULL`); with a
///   password set, recovery is refused (`account_not_reset`).
/// - Completion stores the Argon2id hash under a row lock, audits
///   `employee.access.recovered`, then uses up the QR and issues a session.
/// - An interrupted completion can be finished by the same device with the
///   same password (a new session, nothing written).
class RecoveryService {
  RecoveryService({
    required this._accounts,
    required this._credentials,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._sessions,
    required this._temporaryQr,
    this._hasher = const PasswordHasher(),
  });

  final OnboardingRepository _accounts;
  final CredentialRepository _credentials;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final SqlExecutor _executor;
  final SessionTokens _sessions;
  final TemporaryQrService _temporaryQr;
  final PasswordHasher _hasher;

  /// Checks a scanned recovery QR; returns the account whose password will
  /// be set.
  Future<EmployeeAccount> start(String qrCode) async {
    final claims = await _temporaryQr.check(qrCode, TemporaryQrPurpose.recovery);
    final user = await _requireReset(_executor, await _accounts.findById(_executor, claims.userId));
    return AccountSetupRules.account(_accounts, _executor, user);
  }

  Future<SessionResponse> complete(RecoveryCompleteRequest request) async {
    PasswordPolicy.check(request.password);
    final deviceId = checkedDeviceId(request.deviceId, field: RecoveryCompleteRequest.fieldDeviceId);
    return _temporaryQr.redeem(
      request.qrCode,
      TemporaryQrPurpose.recovery,
      deviceId,
      (claims, {required isRetry}) => _complete(claims, request.password, deviceId, isRetry: isRetry),
    );
  }

  Future<SessionResponse> _complete(TemporaryQrClaims claims, String password, String deviceId, {required bool isRetry}) async {
    final found = await _accounts.findById(_executor, claims.userId);
    if (found != null && AccountSetupRules.isUsable(found) && found.passwordSet && isRetry) {
      final hash = await _accounts.passwordHash(_executor, found.userId);
      if (hash == null || !await _hasher.verify(password, hash)) throw _notReset();
      return _session(found, deviceId, hash, await AccountSetupRules.account(_accounts, _executor, found));
    }
    await _requireReset(_executor, found);
    final hash = await _hasher.hash(password);

    final (user, account) = await _transactions.transaction((tx) async {
      final user = await _requireReset(tx, await _accounts.findById(tx, claims.userId, lockForUpdate: true));
      if (!await _credentials.setPasswordAfterReset(tx, user.userId, hash)) throw _notReset();
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.accessRecovered,
          actorUserId: user.userId,
          references: {EventLogReference.user: user.userId},
        ),
      );
      return (user, await AccountSetupRules.account(_accounts, tx, user));
    });
    return _session(user, deviceId, hash, account);
  }

  SessionResponse _session(OnboardingUser user, String deviceId, String hash, EmployeeAccount account) {
    final session = _sessions.issue(userId: user.userId, deviceId: deviceId, passwordHash: hash);
    return SessionResponse(
      account: account,
      session: SessionInfo(accessToken: session.token, expiresAt: session.expiresAt),
    );
  }

  /// Recovery needs an HR-authorized reset: no password and the reset is the
  /// newest access event. A never-activated account onboards instead.
  Future<OnboardingUser> _requireReset(SqlExecutor executor, OnboardingUser? user) async {
    final usable = AccountSetupRules.requireUsable(user);
    final state = await AccountSetupRules.stateOf(_accounts, executor, usable);
    if (state != AccountSetupState.resetPending) throw _notReset();
    return usable;
  }

  static ApiException _notReset() => AccountSetupRules.notReset();
}
