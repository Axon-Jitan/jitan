import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../auth/password_hasher.dart';
import '../auth/password_policy.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'onboarding_repository.dart';

/// Employee onboarding with the personal QR (`tblUser.userQRcode`).
///
/// The rule (decision 2026-10-07): `userPassword IS NULL` → onboarding can
/// start; setting the password is mandatory and completes it; once a password
/// is set, the same QR can never restart onboarding. It stays valid for
/// Jitan Terminal.
///
/// The QR is the credential here (the employee has no password yet): 144
/// random bits, so it cannot be guessed.
class OnboardingService {
  OnboardingService({
    required this._onboarding,
    required this._audit,
    required this._transactions,
    required this._executor,
    this._hasher = const PasswordHasher(),
  });

  final OnboardingRepository _onboarding;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;

  /// For reads outside a transaction.
  final SqlExecutor _executor;
  final PasswordHasher _hasher;

  /// Longest QR value accepted, as a cheap sanity bound.
  static const maxQrCodeLength = 256;

  /// Checks a scanned QR and returns the account to confirm.
  Future<OnboardingAccount> start(String qrCode) async {
    final user = _requireOnboardable(await _onboarding.findByQrCode(_executor, _checkedQr(qrCode)));
    return _account(_executor, user);
  }

  /// Sets the employee's first password, which completes onboarding.
  Future<OnboardingAccount> complete(String qrCode, String password) async {
    final qr = _checkedQr(qrCode);
    PasswordPolicy.check(password);

    // Refuse before the (slow) hash when onboarding is already done…
    _requireOnboardable(await _onboarding.findByQrCode(_executor, qr));
    final hash = await _hasher.hash(password);

    // …and check again under a row lock: only one device can complete.
    return _transactions.transaction((tx) async {
      final user = _requireOnboardable(await _onboarding.findByQrCode(tx, qr, lockForUpdate: true));
      if (!await _onboarding.setPasswordIfNotSet(tx, user.userId, hash)) throw _alreadyCompleted();
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.onboardingCompleted,
          actorUserId: user.userId,
          references: {EventLogReference.user: user.userId},
        ),
      );
      return _account(tx, user);
    });
  }

  static String _checkedQr(String qrCode) {
    final qr = qrCode.trim();
    if (qr.isEmpty || qr.length > maxQrCodeLength) {
      throw const ApiException(400, ApiErrorCode.invalidQrCode, 'This is not a Jitan QR code.');
    }
    return qr;
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

  Future<OnboardingAccount> _account(SqlExecutor executor, OnboardingUser user) async => OnboardingAccount(
        firstName: user.firstName,
        lastName: user.lastName,
        code: user.code,
        companies: await _onboarding.companyNames(executor, user.userId),
      );
}
