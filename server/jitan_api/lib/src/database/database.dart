import 'dart:async';
import 'dart:io';

import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../config/database_config.dart';
import 'database_exception.dart';
import 'db_row.dart';

/// The server's single gateway to MySQL. Only repositories use it.
///
/// Statements use named parameters (`:name`). Values are escaped by the
/// driver; only `String`, `int`, `bool` and `null` are accepted so nothing
/// is stringified implicitly.
class Database {
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

  /// Server errors that mean "cannot use the database", not "bad statement":
  /// 1040 too many connections, 1044/1045 access denied, 1049 unknown database.
  static const _connectionErrorCodes = {1040, 1044, 1045, 1049};

  Future<List<DbRow>> query(String sql, [Map<String, Object?> params = const {}]) async {
    _checkParams(params);
    final IResultSet result;
    try {
      result = await _pool.execute(sql, params);
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
    return [for (final row in result.rows) DbRow(row.assoc())];
  }

  Future<void> close() => _pool.close();

  static void _checkParams(Map<String, Object?> params) {
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null || value is String || value is int || value is bool) continue;
      throw ArgumentError.value(
        value,
        entry.key,
        'SQL parameters must be String, int, bool or null; convert explicitly.',
      );
    }
  }
}
