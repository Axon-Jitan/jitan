import '../database/database.dart';

/// Checks that the database answers queries.
class DatabaseHealthRepository {
  const DatabaseHealthRepository(this._db);

  final Database _db;

  /// Runs `SELECT 1`. Throws `DatabaseUnavailableException` when unreachable.
  Future<void> ping() async {
    final rows = await _db.query('SELECT 1 AS ok');
    if (rows.length != 1 || rows.single.readInt('ok') != 1) {
      throw StateError('SELECT 1 returned an unexpected result.');
    }
  }
}
