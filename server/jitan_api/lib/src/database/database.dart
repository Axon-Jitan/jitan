import 'dart:async';
import 'dart:io';

import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../config/database_config.dart';
import 'database_exception.dart';
import 'db_row.dart';
import 'sql_executor.dart';

/// The server's single gateway to MySQL. Only repositories and services
/// (for [transaction]) use it.
class Database implements SqlExecutor, TransactionRunner {
  Database._(this._pool);

  factory Database.connect(DatabaseConfig config, {int maxConnections = 10}) {
    return Database._(
      MySQLConnectionPool(
        host: config.host,
        port: config.port,
        userName: config.user,
        password: config.password,
        databaseName: config.name,
        maxConnections: maxConnections,
        secure: config.secure,
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

  @override
  Future<T> transaction<T>(Future<T> Function(SqlExecutor tx) action) =>
      _run(() => _pool.transactional((connection) => action(_ConnectionExecutor(connection))));

  Future<void> close() => _pool.close();
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
  } on MySQLServerException catch (e) {
    if (_connectionErrorCodes.contains(e.errorCode)) {
      throw DatabaseUnavailableException('MySQL error ${e.errorCode}: ${e.message}');
    }
    throw DatabaseQueryException(e.message, errorCode: e.errorCode);
  } on MySQLClientException catch (e) {
    throw DatabaseUnavailableException(e.message);
  } on IOException catch (e) {
    throw DatabaseUnavailableException(e);
  } on TimeoutException catch (e) {
    throw DatabaseUnavailableException(e);
  }
}

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
