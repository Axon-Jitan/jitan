import 'package:jitan_models/jitan_models.dart';

/// An expected failure with a client-facing status, code and message.
/// Thrown by services/routes; turned into JSON by the error middleware.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  const ApiException.badRequest(String message) : this(400, ApiErrorCode.badRequest, message);

  const ApiException.unauthenticated(String message)
      : this(401, ApiErrorCode.unauthenticated, message);

  const ApiException.forbidden(String message) : this(403, ApiErrorCode.forbidden, message);

  const ApiException.notFound(String message) : this(404, ApiErrorCode.notFound, message);

  /// The stored data is inconsistent with what the request needs.
  const ApiException.configurationError(String message)
      : this(409, ApiErrorCode.configurationError, message);

  final int statusCode;
  final String code;
  final String message;

  ApiError toApiError() => ApiError(code: code, message: message);

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}
