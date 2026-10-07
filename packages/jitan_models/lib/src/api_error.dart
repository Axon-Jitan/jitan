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
