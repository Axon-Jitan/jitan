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

  /// 1062: a UNIQUE key (e.g. `tblUser.userCode`) already holds the value.
  bool get isDuplicateKey => errorCode == 1062;

  /// 1406: a value is longer than its column allows.
  bool get isValueTooLong => errorCode == 1406;

  /// 1213: MySQL chose this transaction as a deadlock victim and rolled it
  /// back entirely; it may be retried as a whole.
  bool get isDeadlock => errorCode == 1213;

  @override
  String toString() => 'DatabaseQueryException(${errorCode ?? '-'}): $cause';
}
