import 'dart:async';
import 'dart:io';

import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../config/database_config.dart';
import 'connection_pool.dart';
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
      ConnectionPool<MySQLConnection>(
        open: () async {
          final connection = await MySQLConnection.createConnection(
            host: config.host,
            port: config.port,
            userName: config.user,
            password: config.password,
            databaseName: config.name,
            secure: config.secure,
            securityContext: tls.context,
            onBadCertificate: tls.onBadCertificate,
            collation: 'utf8mb4_general_ci',
          );
          await connection.connect(timeoutMs: _connectTimeout.inMilliseconds);
          return connection;
        },
        isOpen: (connection) => connection.connected,
        close: (connection) => connection.close(),
        maxConnections: maxConnections,
      ),
    );
  }

  static const _connectTimeout = Duration(seconds: 10);

  final ConnectionPool<MySQLConnection> _pool;

  @override
  Future<List<DbRow>> query(String sql, [Map<String, Object?> params = const {}]) async =>
      _rows(await _run(() => _pool.withConnection((c) => c.execute(sql, _checked(params)))));

  @override
  Future<SqlWriteResult> execute(String sql, [Map<String, Object?> params = const {}]) async =>
      _writeResult(await _run(() => _pool.withConnection((c) => c.execute(sql, _checked(params)))));

  /// Runs [action] in one transaction on one connection: COMMIT when it
  /// completes, ROLLBACK when it throws, and the error is rethrown.
  ///
  /// The connection always goes back to the pool, also when [action]
  /// throws (the driver's `transactional` and pool did not release it,
  /// mysql_client_plus 0.1.3). START, COMMIT and ROLLBACK are Jitan's own:
  /// when the ROLLBACK fails, the driver would keep the connection "in a
  /// transaction" for good; here the connection is discarded instead, and
  /// closing it makes MySQL roll back and free its locks (review L8). The
  /// error of [action], not the ROLLBACK's, is the one rethrown.
  @override
  Future<T> transaction<T>(Future<T> Function(SqlExecutor tx) action, {String? serializedBy}) async {
    final outcome = await _run(
      () async => _pool.withConnection((connection) async {
        var locked = false;
        try {
          if (serializedBy != null) {
            locked = await _namedLock(connection, serializedBy);
          }
          await connection.execute('START TRANSACTION');
          try {
            final value = await action(_ConnectionExecutor(connection));
            await connection.execute('COMMIT');
            return _Outcome<T>.value(value);
          } catch (error, stackTrace) {
            try {
              await connection.execute('ROLLBACK');
            } catch (_) {
              _pool.discard(connection);
            }
            return _Outcome<T>.error(error, stackTrace);
          }
        } catch (error, stackTrace) {
          return _Outcome<T>.error(error, stackTrace);
        } finally {
          if (locked) {
            try {
              await connection.execute('DO RELEASE_LOCK(:name)', {'name': _lockName(serializedBy!)});
            } catch (_) {
              // Closing the connection frees the lock.
              _pool.discard(connection);
            }
          }
        }
      }),
    );
    return outcome.unwrap();
  }

  /// How long a transaction waits for a named lock before giving up (503).
  static const namedLockWait = Duration(seconds: 10);

  static String _lockName(String name) => 'jitan.$name';

  /// Takes the named lock on [connection]; throws when it isn't free in time.
  static Future<bool> _namedLock(MySQLConnection connection, String name) async {
    final result = await connection.execute('SELECT GET_LOCK(:name, :wait) AS got', {
      'name': _lockName(name),
      'wait': namedLockWait.inSeconds,
    });
    final got = result.rows.firstOrNull?.colByName('got');
    if (got != '1') throw DatabaseUnavailableException('The lock "$name" was not free within ${namedLockWait.inSeconds} s.');
    return true;
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
