import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import 'onboarding_repository.dart';

/// Checks shared by onboarding and password recovery: both set the first
/// password of a user that a temporary QR names.
abstract final class AccountSetupRules {
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
