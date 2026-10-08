import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/device_id.dart';
import '../auth/password_hasher.dart';
import '../auth/password_policy.dart';
import '../auth/session_tokens.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../languages/language_repository.dart';
import '../temporary_qr/temporary_qr_service.dart';
import '../temporary_qr/temporary_qr_tokens.dart';
import 'account_setup_rules.dart';
import 'onboarding_repository.dart';

/// Employee onboarding with a **temporary onboarding QR** (IT decision
/// 2026-10-08): HR/Admin generates it; the employee scans it, confirms who
/// they are and sets the mandatory password, which signs the device in (no
/// second sign-in). The permanent Terminal QR never onboards anyone.
///
/// - The QR must be valid, unexpired, the current one, unused, and for
///   onboarding ([TemporaryQrService]); scanning does not use it up.
/// - `userPassword IS NULL` is still the "not yet set up" signal; once a
///   password is set, onboarding is refused (`onboarding_already_completed`).
/// - Completion stores the Argon2id hash under a row lock (only one device
///   can complete), audits, then uses up the QR and issues the session.
/// - If the answer was lost, the **same device** may repeat the completion
///   with the same QR and the **same password**: it gets a new session and
///   nothing is written. Any other password, or another device, is refused.
class OnboardingService {
  OnboardingService({
    required this._onboarding,
    required this._languages,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._sessions,
    required this._temporaryQr,
    this._hasher = const PasswordHasher(),
  });

  final OnboardingRepository _onboarding;
  final LanguageRepository _languages;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;

  /// For reads outside a transaction.
  final SqlExecutor _executor;
  final SessionTokens _sessions;
  final TemporaryQrService _temporaryQr;
  final PasswordHasher _hasher;

  /// Code of the built-in default language; it needs no database row.
  static const _englishCode = 'en';

  /// Checks a scanned onboarding QR and returns the account to confirm.
  Future<EmployeeAccount> start(String qrCode) async {
    final claims = await _temporaryQr.check(qrCode, TemporaryQrPurpose.onboarding);
    final user = await _requireOnboardable(_executor, await _onboarding.findById(_executor, claims.userId));
    return _account(_executor, user);
  }

  /// Completes onboarding and signs the device in. Cheap checks first, then
  /// the QR is held for this device while the password is stored.
  Future<SessionResponse> complete(OnboardingCompleteRequest request) async {
    PasswordPolicy.check(request.password);
    final deviceId = checkedDeviceId(request.deviceId, field: OnboardingCompleteRequest.fieldDeviceId);
    final languageId = await _languageIdFor(request.languageCode);
    return _temporaryQr.redeem(
      request.qrCode,
      TemporaryQrPurpose.onboarding,
      deviceId,
      (claims, {required isRetry}) => _complete(claims, request.password, deviceId, languageId, isRetry: isRetry),
    );
  }

  Future<SessionResponse> _complete(
    TemporaryQrClaims claims,
    String password,
    String deviceId,
    int? languageId, {
    required bool isRetry,
  }) async {
    final found = await _onboarding.findById(_executor, claims.userId);
    if (found != null && AccountSetupRules.isUsable(found) && found.passwordSet && isRetry) {
      return _sessionAgain(found, password, deviceId);
    }
    // Refuse before the (slow) hash when onboarding cannot run…
    await _requireOnboardable(_executor, found);
    final hash = await _hasher.hash(password);

    // …and check again under a row lock: only one device can complete.
    final (user, account) = await _transactions.transaction((tx) async {
      final user = await _requireOnboardable(tx, await _onboarding.findById(tx, claims.userId, lockForUpdate: true));
      if (!await _onboarding.setPasswordIfNotSet(tx, user.userId, hash)) throw AccountSetupRules.alreadyCompleted();
      if (languageId != null) await _onboarding.setLanguage(tx, user.userId, languageId);
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.onboardingCompleted,
          actorUserId: user.userId,
          references: {EventLogReference.user: user.userId},
        ),
      );
      return (user, await _account(tx, user));
    });
    return _session(user.userId, deviceId, hash, account);
  }

  /// The same device finishing an interrupted completion: a new session only
  /// when [password] matches the hash it stored. Nothing is written.
  Future<SessionResponse> _sessionAgain(OnboardingUser user, String password, String deviceId) async {
    final hash = await _onboarding.passwordHash(_executor, user.userId);
    if (hash == null || !await _hasher.verify(password, hash)) throw AccountSetupRules.alreadyCompleted();
    return _session(user.userId, deviceId, hash, await _account(_executor, user));
  }

  SessionResponse _session(int userId, String deviceId, String hash, EmployeeAccount account) {
    final session = _sessions.issue(userId: userId, deviceId: deviceId, passwordHash: hash);
    return SessionResponse(
      account: account,
      session: SessionInfo(accessToken: session.token, expiresAt: session.expiresAt),
    );
  }

  /// The active `tblLanguage` row for [code]; `null` for no choice or for
  /// English without a database row (built-in default). An unknown or
  /// inactive non-English code is a validation error.
  Future<int?> _languageIdFor(String? code) async {
    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final language = await _languages.findActiveByCode(trimmed);
    if (language != null) return language.id;
    if (trimmed == _englishCode) return null;
    throw const ApiException.validation(OnboardingCompleteRequest.fieldLanguageCode, 'Choose an available language.');
  }

  /// Only an account that never had a password may onboard. An account whose
  /// access was reset recovers instead (a separate operation).
  Future<OnboardingUser> _requireOnboardable(SqlExecutor executor, OnboardingUser? user) async {
    final usable = AccountSetupRules.requireUsable(user);
    final state = await AccountSetupRules.stateOf(_onboarding, executor, usable);
    if (state != AccountSetupState.neverActivated) throw AccountSetupRules.alreadyCompleted();
    return usable;
  }

  Future<EmployeeAccount> _account(SqlExecutor executor, OnboardingUser user) => AccountSetupRules.account(_onboarding, executor, user);
}
