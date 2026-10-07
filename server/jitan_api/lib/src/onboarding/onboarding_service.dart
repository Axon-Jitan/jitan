import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/password_hasher.dart';
import '../auth/password_policy.dart';
import '../auth/session_tokens.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../languages/language_repository.dart';
import 'onboarding_repository.dart';

/// Employee onboarding with the personal QR (`tblUser.userQRcode`).
///
/// Rules (decisions 2026-10-07):
/// - `userPassword IS NULL` → onboarding can start.
/// - Setting a password is mandatory and completes onboarding.
/// - Once a password is set, the same QR never restarts onboarding; it stays
///   valid for Jitan Terminal.
/// - Completing onboarding signs the device in: no second sign-in.
/// - Session recovery: if the response to a completed onboarding was lost
///   (network), repeating the request with the **same password** returns a
///   new session and changes nothing. Any other password gets 409, so this is
///   never a way to replace a password.
///
/// The QR is the credential here (the employee has no password yet): 144
/// random bits, so it cannot be guessed.
class OnboardingService {
  OnboardingService({
    required this._onboarding,
    required this._languages,
    required this._audit,
    required this._transactions,
    required this._executor,
    required this._sessions,
    this._hasher = const PasswordHasher(),
  });

  final OnboardingRepository _onboarding;
  final LanguageRepository _languages;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;

  /// For reads outside a transaction.
  final SqlExecutor _executor;
  final SessionTokens _sessions;
  final PasswordHasher _hasher;

  /// Longest QR value accepted, as a cheap sanity bound.
  static const maxQrCodeLength = 256;

  /// Code of the built-in default language; it needs no database row.
  static const _englishCode = 'en';

  static final _deviceIdFormat = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

  /// Checks a scanned QR and returns the account to confirm.
  Future<EmployeeAccount> start(String qrCode) async {
    final user = _requireOnboardable(await _onboarding.findByQrCode(_executor, _checkedQr(qrCode)));
    return _account(_executor, user);
  }

  /// Completes onboarding in one transaction and signs the device in:
  /// row lock → guard re-check → password hash stored (only while none is
  /// set) → chosen language stored → audit → session for [request.deviceId].
  Future<OnboardingCompleteResponse> complete(OnboardingCompleteRequest request) async {
    final qr = _checkedQr(request.qrCode);
    PasswordPolicy.check(request.password);
    final deviceId = _checkedDeviceId(request.deviceId);
    final languageId = await _languageIdFor(request.languageCode);

    final found = await _onboarding.findByQrCode(_executor, qr);
    if (found != null && found.isActive && found.passwordSet) {
      return _recoverSession(found, request.password, deviceId);
    }

    // Refuse before the (slow) hash when onboarding cannot run…
    _requireOnboardable(found);
    final hash = await _hasher.hash(request.password);

    // …and check again under a row lock: only one device can complete.
    final (user, account) = await _transactions.transaction((tx) async {
      final user = _requireOnboardable(await _onboarding.findByQrCode(tx, qr, lockForUpdate: true));
      if (!await _onboarding.setPasswordIfNotSet(tx, user.userId, hash)) throw _alreadyCompleted();
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

    final session = _sessions.issue(userId: user.userId, deviceId: deviceId, passwordHash: hash);
    return OnboardingCompleteResponse(
      account: account,
      session: SessionInfo(accessToken: session.token, expiresAt: session.expiresAt),
    );
  }

  /// Onboarding already completed: a new session only when [password]
  /// matches the stored hash (the same employee retrying after a lost
  /// response, Figma "Session recovery"). Nothing is written.
  Future<OnboardingCompleteResponse> _recoverSession(OnboardingUser user, String password, String deviceId) async {
    final hash = await _onboarding.passwordHash(_executor, user.userId);
    if (hash == null || !await _hasher.verify(password, hash)) throw _alreadyCompleted();
    final session = _sessions.issue(userId: user.userId, deviceId: deviceId, passwordHash: hash);
    return OnboardingCompleteResponse(
      account: await _account(_executor, user),
      session: SessionInfo(accessToken: session.token, expiresAt: session.expiresAt),
    );
  }

  static String _checkedQr(String qrCode) {
    final qr = qrCode.trim();
    if (qr.isEmpty || qr.length > maxQrCodeLength) {
      throw const ApiException(400, ApiErrorCode.invalidQrCode, 'This is not a Jitan QR code.');
    }
    return qr;
  }

  static String _checkedDeviceId(String deviceId) {
    if (!_deviceIdFormat.hasMatch(deviceId)) {
      throw const ApiException.validation(OnboardingCompleteRequest.fieldDeviceId, 'Invalid device identifier.');
    }
    return deviceId;
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

  static OnboardingUser _requireOnboardable(OnboardingUser? user) {
    // Unknown and deleted users get the same answer: nothing is revealed.
    if (user == null) throw const ApiException(404, ApiErrorCode.invalidQrCode, 'This is not a Jitan QR code.');
    if (!user.isActive) {
      throw const ApiException(403, ApiErrorCode.accountInactive, 'This account is not active.');
    }
    if (user.passwordSet) throw _alreadyCompleted();
    return user;
  }

  static ApiException _alreadyCompleted() => const ApiException(
        409,
        ApiErrorCode.onboardingAlreadyCompleted,
        'Onboarding is already completed for this account.',
      );

  Future<EmployeeAccount> _account(SqlExecutor executor, OnboardingUser user) async => EmployeeAccount(
        firstName: user.firstName,
        lastName: user.lastName,
        code: user.code,
        companies: await _onboarding.companyNames(executor, user.userId),
      );
}
