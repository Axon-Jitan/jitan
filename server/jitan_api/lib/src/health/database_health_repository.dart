import '../database/database.dart';
import '../database/database_exception.dart';

/// Checks that the database answers queries, in a mode Jitan can use.
class DatabaseHealthRepository {
  const DatabaseHealthRepository(this._db);

  final Database _db;

  /// Why the database can't be used as it is configured.
  ///
  /// The driver (mysql_client_plus) fills parameters in on the client and
  /// escapes them with backslashes. With the SQL mode `NO_BACKSLASH_ESCAPES`
  /// those backslashes are kept as text, so every stored `\` would be
  /// doubled (review L13). Quotes stay safe either way.
  static const backslashModeProblem =
      'The database runs with the SQL mode NO_BACKSLASH_ESCAPES, which Jitan does not support: '
      'stored text with a backslash would be changed. Remove it from sql_mode for Jitan\'s account.';

  /// Runs `SELECT 1` and checks the SQL mode. Throws
  /// `DatabaseUnavailableException` when unreachable or in a mode Jitan
  /// can't use ([backslashModeProblem]).
  Future<void> ping() async {
    final rows = await _db.query(
      "SELECT 1 AS ok, FIND_IN_SET('NO_BACKSLASH_ESCAPES', @@SESSION.sql_mode) > 0 AS backslashMode",
    );
    if (rows.length != 1 || rows.single.readInt('ok') != 1) {
      throw StateError('SELECT 1 returned an unexpected result.');
    }
    if (rows.single.readBool('backslashMode')) throw DatabaseUnavailableException(backslashModeProblem);
  }
}
