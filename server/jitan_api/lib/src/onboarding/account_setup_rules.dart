import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'onboarding_repository.dart';

/// Where an account stands for setting its password.
enum AccountSetupState {
  /// `userPassword IS NOT NULL`: neither onboarding nor recovery.
  activated,

  /// No password and no account-access event yet: onboarding only.
  neverActivated,

  /// No password and the newest access event is HR/Admin "Reset account
  /// access": recovery only. This is the HR-authorized recovery operation.
  resetPending,

  /// No password, but the newest access event is a completed onboarding or
  /// recovery (the password was cleared outside Jitan, or the event types
  /// are missing: CLARIFY-11). Neither flow is allowed; HR/Admin must look.
  unexplained,
}

/// Checks shared by onboarding and password recovery: both set the first
/// password of a user that a temporary QR names, but they are separate
/// operations. Onboarding is only for an account that never had a password;
/// recovery only for one whose access HR/Admin reset (its
/// `employee.access.reset` event is the newest access event).
abstract final class AccountSetupRules {
  static final _accessEvents = [
    AuditEventType.onboardingCompleted.typeName,
    AuditEventType.accountAccessReset.typeName,
    AuditEventType.accessRecovered.typeName,
  ];

  static Future<AccountSetupState> stateOf(OnboardingRepository accounts, SqlExecutor executor, OnboardingUser user) async {
    if (user.passwordSet) return AccountSetupState.activated;
    return switch (await accounts.latestAccessEvent(executor, user.userId, _accessEvents)) {
      null => AccountSetupState.neverActivated,
      final name when name == AuditEventType.accountAccessReset.typeName => AccountSetupState.resetPending,
      _ => AccountSetupState.unexplained,
    };
  }

  static ApiException notReset() => const ApiException(
        409,
        ApiErrorCode.accountNotReset,
        'Recovery needs HR/Admin to reset your access first.',
      );

  /// Active and not marked for deletion.
  static bool isUsable(OnboardingUser user) => user.isActive && !user.isMarkedForDeletion;

  /// The user, or 400 `invalid_qr_code` when the QR names nobody (generic, so
  /// nothing is revealed) and 403 `account_inactive` when the account is
  /// inactive or MFD.
  static OnboardingUser requireUsable(OnboardingUser? user) {
    if (user == null) throw const ApiException(400, ApiErrorCode.invalidQrCode, 'This is not a valid Jitan QR code.');
    if (!isUsable(user)) throw const ApiException(403, ApiErrorCode.accountInactive, 'This account is not active.');
    return user;
  }

  static ApiException alreadyCompleted() => const ApiException(
        409,
        ApiErrorCode.onboardingAlreadyCompleted,
        'Onboarding is already completed for this account.',
      );

  /// Who the employee is, for "Is this you?" and the signed-in app.
  static Future<EmployeeAccount> account(OnboardingRepository accounts, SqlExecutor executor, OnboardingUser user) async =>
      EmployeeAccount(
        firstName: user.firstName,
        lastName: user.lastName,
        code: user.code,
        companies: await accounts.companyNames(executor, user.userId),
      );
}
