import 'json_reading.dart';

/// Machine-readable error codes returned by the Jitan API.
///
/// Clients branch on these codes, never on the human-readable message.
abstract final class ApiErrorCode {
  static const badRequest = 'bad_request';

  /// A request field failed validation; [ApiError.field] names it.
  static const validationFailed = 'validation_failed';

  /// `tblUser.userCode` is already used by another user.
  static const duplicateEmployeeCode = 'duplicate_employee_code';

  /// The scanned QR is not a known employee's personal QR.
  static const invalidQrCode = 'invalid_qr_code';

  /// The employee's account is disabled; onboarding is not possible.
  static const accountInactive = 'account_inactive';

  /// The employee already completed onboarding (a password is set). The same
  /// QR stays valid for Jitan Terminal but cannot restart onboarding.
  static const onboardingAlreadyCompleted = 'onboarding_already_completed';
  /// Sign-in failed. Deliberately generic: never says whether the employee
  /// code or the password was wrong.
  static const invalidCredentials = 'invalid_credentials';

  /// Reset account access on an employee who has not set up Jitan yet.
  static const accountNotActivated = 'account_not_activated';
  static const unauthenticated = 'unauthenticated';
  static const forbidden = 'forbidden';
  static const notFound = 'not_found';

  /// Data in the database is inconsistent with what the operation needs
  /// (e.g. several languages assigned to one user). Not retryable by the user.
  static const configurationError = 'configuration_error';
  static const databaseUnavailable = 'database_unavailable';
  static const internalError = 'internal_error';
}

/// The error body every non-2xx API response carries:
///
/// ```json
/// { "error": { "code": "validation_failed", "message": "...", "field": "code" } }
/// ```
///
/// `field` is present only when the error concerns one request field.
class ApiError {
  const ApiError({required this.code, required this.message, this.field});

  factory ApiError.fromJson(Map<String, Object?> json) {
    final error = json.readObject('error');
    return ApiError(
      code: error.readString('code'),
      message: error.readString('message'),
      field: error.readOptionalString('field'),
    );
  }

  final String code;
  final String message;

  /// The request field this error is about, e.g. `code`.
  final String? field;

  Map<String, Object?> toJson() => {
        'error': {'code': code, 'message': message, if (field != null) 'field': field},
      };

  @override
  String toString() => 'ApiError($code: $message)';
}
