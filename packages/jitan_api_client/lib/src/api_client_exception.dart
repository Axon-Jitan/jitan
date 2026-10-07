import 'package:jitan_models/jitan_models.dart';

/// Why an API call failed, from the client's point of view.
enum ApiFailureKind {
  /// No response: offline, DNS, refused connection, timeout.
  network,

  /// The server answered with a structured error ([ApiClientException.error]).
  server,

  /// The server answered with something that is not the agreed contract.
  invalidResponse,
}

/// A failed API call. Screens decide what to show from [kind] and, for
/// server errors, [ApiError.code], never from parsing [message].
class ApiClientException implements Exception {
  const ApiClientException.network(this.message)
      : kind = ApiFailureKind.network,
        statusCode = null,
        error = null;

  const ApiClientException.server(int this.statusCode, ApiError this.error)
      : kind = ApiFailureKind.server,
        message = null;

  const ApiClientException.invalidResponse(this.statusCode, this.message)
      : kind = ApiFailureKind.invalidResponse,
        error = null;

  final ApiFailureKind kind;
  final int? statusCode;
  final ApiError? error;

  /// Diagnostic detail for logs; not for display.
  final String? message;

  @override
  String toString() => 'ApiClientException(${kind.name}, status: $statusCode, '
      '${error ?? message})';
}
