/// The database could not be reached (network, authentication, pool closed).
/// Mapped to HTTP 503.
class DatabaseUnavailableException implements Exception {
  const DatabaseUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'DatabaseUnavailableException: $cause';
}

/// The database was reached but rejected the statement (bad SQL, missing
/// column, constraint violation). Mapped to HTTP 500; details are logged,
/// never returned to the client.
class DatabaseQueryException implements Exception {
  const DatabaseQueryException(this.cause, {this.errorCode});

  final Object cause;

  /// MySQL server error number, when the server reported one.
  final int? errorCode;

  @override
  String toString() => 'DatabaseQueryException(${errorCode ?? '-'}): $cause';
}
