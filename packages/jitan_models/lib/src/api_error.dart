import 'json_reading.dart';

/// Machine-readable error codes returned by the Jitan API.
///
/// Clients branch on these codes, never on the human-readable message.
abstract final class ApiErrorCode {
  static const badRequest = 'bad_request';
  static const unauthenticated = 'unauthenticated';
  static const forbidden = 'forbidden';
  static const notFound = 'not_found';
  static const databaseUnavailable = 'database_unavailable';
  static const internalError = 'internal_error';
}

/// The error body every non-2xx API response carries:
///
/// ```json
/// { "error": { "code": "forbidden", "message": "..." } }
/// ```
class ApiError {
  const ApiError({required this.code, required this.message});

  factory ApiError.fromJson(Map<String, Object?> json) {
    final error = json.readObject('error');
    return ApiError(
      code: error.readString('code'),
      message: error.readString('message'),
    );
  }

  final String code;
  final String message;

  Map<String, Object?> toJson() => {
        'error': {'code': code, 'message': message},
      };

  @override
  String toString() => 'ApiError($code: $message)';
}
