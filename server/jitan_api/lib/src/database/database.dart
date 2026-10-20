import 'dart:async';
import 'dart:io';

import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../config/database_config.dart';
import 'database_exception.dart';
import 'database_tls.dart';
import 'db_row.dart';
import 'sql_executor.dart';

/// The server's single gateway to MySQL. Only repositories and services
/// (for [transaction]) use it.
class Database implements SqlExecutor, TransactionRunner {
  Database._(this._pool);

  /// Fails with a ConfigException when the TLS settings can't be loaded.
  factory Database.connect(DatabaseConfig config, {int maxConnections = 10}) {
    final tls = DatabaseTls.of(config);
    return Database._(
      MySQLConnectionPool(
        host: config.host,
        port: config.port,
        userName: config.user,
        password: config.password,
        databaseName: config.name,
        maxConnections: maxConnections,
        secure: config.secure,
        securityContext: tls.context,
        onBadCertificate: tls.onBadCertificate,
        collation: 'utf8mb4_general_ci',
      ),
    );
  }

  final MySQLConnectionPool _pool;

  @override
  Future<List<DbRow>> query(String sql, [Map<String, Object?> params = const {}]) async =>
      _rows(await _run(() => _pool.execute(sql, _checked(params))));

  @override
  Future<SqlWriteResult> execute(String sql, [Map<String, Object?> params = const {}]) async =>
      _writeResult(await _run(() => _pool.execute(sql, _checked(params))));

  /// Runs [action] in one transaction on one connection: COMMIT when it
  /// completes, ROLLBACK when it throws, and the error is rethrown.
  ///
  /// The connection is always returned to the pool. The driver's own
  /// `MySQLConnectionPool.transactional` does not release it when the
  /// callback throws (mysql_client_plus 0.1.3), so every failed transaction
  /// would leak a connection until the pool is exhausted and all requests
  /// wait forever. Here the failure is caught inside the pool callback and
  /// rethrown only after the connection is back in the pool.
  @override
  Future<T> transaction<T>(Future<T> Function(SqlExecutor tx) action) async {
    final outcome = await _run(
      () async => _pool.withConnection((connection) async {
        try {
          return _Outcome<T>.value(
            await connection.transactional((tx) => action(_ConnectionExecutor(tx))),
          );
        } catch (error, stackTrace) {
          return _Outcome<T>.error(error, stackTrace);
        }
      }),
    );
    return outcome.unwrap();
  }

  Future<void> close() => _pool.close();
}

/// A transaction's result or failure, carried out of the pool callback so
/// the connection is released before the failure is rethrown.
class _Outcome<T> {
  _Outcome.value(T this._value) : _error = null, _stackTrace = null;
  _Outcome.error(Object this._error, StackTrace this._stackTrace) : _value = null;

  final T? _value;
  final Object? _error;
  final StackTrace? _stackTrace;

  T unwrap() {
    final error = _error;
    if (error != null) Error.throwWithStackTrace(_mapDriverError(error), _stackTrace!);
    return _value as T;
  }
}

/// The single connection a transaction runs on.
class _ConnectionExecutor implements SqlExecutor {
  _ConnectionExecutor(this._connection);

  final MySQLConnection _connection;

  @override
  Future<List<DbRow>> query(String sql, [Map<String, Object?> params = const {}]) async =>
      _rows(await _run(() => _connection.execute(sql, _checked(params))));

  @override
  Future<SqlWriteResult> execute(String sql, [Map<String, Object?> params = const {}]) async =>
      _writeResult(await _run(() => _connection.execute(sql, _checked(params))));
}

/// Server errors that mean "cannot use the database", not "bad statement":
/// 1040 too many connections, 1044/1045 access denied, 1049 unknown database.
const _connectionErrorCodes = {1040, 1044, 1045, 1049};

/// Runs a driver call and maps driver failures to [DatabaseUnavailableException]
/// or [DatabaseQueryException]. Any other exception (e.g. an ApiException
/// thrown inside a transaction) passes through unchanged.
Future<T> _run<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (e) {
    final mapped = _mapDriverError(e);
    if (identical(mapped, e)) rethrow;
    throw mapped;
  }
}

/// The Jitan exception for a driver failure; anything else unchanged.
Object _mapDriverError(Object e) => switch (e) {
  MySQLServerException(:final errorCode, :final message) when _connectionErrorCodes.contains(errorCode) =>
    DatabaseUnavailableException('MySQL error $errorCode: $message'),
  MySQLServerException(:final errorCode, :final message) => DatabaseQueryException(message, errorCode: errorCode),
  MySQLClientException(:final message) => DatabaseUnavailableException(message),
  IOException() || TimeoutException() => DatabaseUnavailableException(e),
  _ => e,
};

List<DbRow> _rows(IResultSet result) => [for (final row in result.rows) DbRow(row.assoc())];

SqlWriteResult _writeResult(IResultSet result) => SqlWriteResult(
      affectedRows: result.affectedRows.toInt(),
      lastInsertId: result.lastInsertID.toInt(),
    );

Map<String, Object?> _checked(Map<String, Object?> params) {
  for (final entry in params.entries) {
    final value = entry.value;
    if (value == null || value is String || value is int || value is bool) continue;
    throw ArgumentError.value(value, entry.key, 'SQL parameters must be String, int, bool or null; convert explicitly.');
  }
  return params;
}
