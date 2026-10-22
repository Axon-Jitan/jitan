import '../database/sql_executor.dart';
import '../database/sql_in_list.dart';

/// One `tblTimeReg` row with its type name, as Time records reads it.
/// [active] is `false` for a row switched off (replaced, rejected or
/// non-work); such rows stay as history (nothing is deleted).
typedef RegistrationRow = ({
  int id,
  int userId,
  String typeName,
  DateTime at,
  bool manualEntry,
  String? comment,
  bool active,
});

/// Reads registrations for Time records (TIME_ENGINE_ANALYSIS D4, D9, D14,
/// D31): non-MFD rows, switched off or not; timestamps are UTC.
class TimeRecordRepository {
  const TimeRecordRepository(this._db);

  final SqlExecutor _db;

  /// The registrations of [userIds] from [fromUtc] (inclusive) to [toUtc]
  /// (exclusive), oldest first. Reads through [executor] when given.
  Future<List<RegistrationRow>> registrationsOf(
    List<int> userIds,
    DateTime fromUtc,
    DateTime toUtc, {
    SqlExecutor? executor,
  }) async {
    if (userIds.isEmpty) return const [];
    final users = SqlInList('u', userIds);
    final rows = await (executor ?? _db).query(
      'SELECT tr.timeRegID, tr.userID, t.timeRegTypeName, tr.timeRegTimestamp, tr.timeRegManualEntry, '
      'tr.timeRegComment, tr.timeRegActive '
      'FROM tblTimeReg tr JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID '
      'WHERE tr.userID IN (${users.placeholders}) AND tr.timeRegMFD = 0 '
      'AND tr.timeRegTimestamp >= :from AND tr.timeRegTimestamp < :to '
      'ORDER BY tr.userID, tr.timeRegTimestamp, tr.timeRegID',
      {...users.params, 'from': sqlDateTime(fromUtc), 'to': sqlDateTime(toUtc)},
    );
    return [
      for (final row in rows)
        (
          id: row.readInt('timeRegID'),
          userId: row.readInt('userID'),
          typeName: row.readString('timeRegTypeName'),
          at: row.readUtcDateTime('timeRegTimestamp'),
          manualEntry: row.readOptionalBool('timeRegManualEntry') ?? false,
          comment: row.readOptionalString('timeRegComment'),
          active: row.readBool('timeRegActive'),
        ),
    ];
  }

  /// Row [id] of [userId], or `null` (another employee's, MFD or unknown).
  Future<RegistrationRow?> registrationOf(SqlExecutor executor, int userId, int id) async {
    final rows = await executor.query(
      'SELECT tr.timeRegID, tr.userID, t.timeRegTypeName, tr.timeRegTimestamp, tr.timeRegManualEntry, '
      'tr.timeRegComment, tr.timeRegActive '
      'FROM tblTimeReg tr JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID '
      'WHERE tr.timeRegID = :id AND tr.userID = :userId AND tr.timeRegMFD = 0',
      {'id': id, 'userId': userId},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return (
      id: row.readInt('timeRegID'),
      userId: row.readInt('userID'),
      typeName: row.readString('timeRegTypeName'),
      at: row.readUtcDateTime('timeRegTimestamp'),
      manualEntry: row.readOptionalBool('timeRegManualEntry') ?? false,
      comment: row.readOptionalString('timeRegComment'),
      active: row.readBool('timeRegActive'),
    );
  }

  /// Each of [userIds]' first registration ever (UTC); employees without
  /// one are left out. "No registration" days start from it: before it the
  /// employee did not use Jitan yet.
  Future<Map<int, DateTime>> firstRegistrations(List<int> userIds) async {
    if (userIds.isEmpty) return const {};
    final users = SqlInList('u', userIds);
    final rows = await _db.query(
      'SELECT userID, MIN(timeRegTimestamp) AS firstAt FROM tblTimeReg '
      'WHERE userID IN (${users.placeholders}) AND timeRegMFD = 0 GROUP BY userID',
      users.params,
    );
    return {for (final row in rows) row.readInt('userID'): row.readUtcDateTime('firstAt')};
  }

  /// [time] in UTC as MySQL `DATETIME` text, to the second.
  static String sqlDateTime(DateTime time) {
    final utc = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }
}
