import '../database/database.dart';

/// Data access for `tblUser`.
class UserRepository {
  const UserRepository(this._db);

  final Database _db;

  /// Whether [userId] exists with `userActive = 1` and `userMFD = 0`.
  Future<bool> isActiveUser(int userId) async {
    final rows = await _db.query(
      'SELECT 1 AS found FROM tblUser '
      'WHERE userID = :userId AND userActive = 1 AND userMFD = 0',
      {'userId': userId},
    );
    return rows.isNotEmpty;
  }
}
