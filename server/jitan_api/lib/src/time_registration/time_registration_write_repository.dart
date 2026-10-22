import '../database/sql_executor.dart';

/// Writes to `tblTimeReg` (TIME_ENGINE_ANALYSIS D4–D9). Rows are only ever
/// added; nothing here changes or deletes one. Timestamps are UTC.
///
/// Methods take the [SqlExecutor] of the caller's transaction.
class TimeRegistrationWriteRepository {
  const TimeRegistrationWriteRepository();

  /// The id of the active `tblTimeRegType` named [name], or `null`.
  Future<int?> typeId(SqlExecutor tx, String name) async {
    final rows = await tx.query(
      'SELECT timeRegTypeID FROM tblTimeRegType '
      'WHERE timeRegTypeName = :name AND timeRegTypeActive = 1 AND timeRegTypeMFD = 0 '
      'ORDER BY timeRegTypeID',
      {'name': name},
    );
    return rows.isEmpty ? null : rows.first.readInt('timeRegTypeID');
  }

  /// Locks [userId]'s `tblUser` row until the transaction ends, so one
  /// employee's registrations are written one after the other (a retry and
  /// its original never both pass the duplicate check).
  Future<void> lockUser(SqlExecutor tx, int userId) =>
      tx.query('SELECT userID FROM tblUser WHERE userID = :userId FOR UPDATE', {'userId': userId});

  /// Whether [userId] has any active registration.
  Future<bool> hasAny(SqlExecutor tx, int userId) async => (await tx.query(
        'SELECT 1 AS found FROM tblTimeReg WHERE userID = :userId AND timeRegActive = 1 AND timeRegMFD = 0 LIMIT 1',
        {'userId': userId},
      ))
          .isNotEmpty;

  /// An active row of [userId] with [typeId] at exactly [at] (a retried
  /// request), or `null`.
  Future<int?> findSame(SqlExecutor tx, int userId, int typeId, DateTime at) async {
    final rows = await tx.query(
      'SELECT timeRegID FROM tblTimeReg '
      'WHERE userID = :userId AND timeRegTypeID = :typeId AND timeRegTimestamp = :at '
      'AND timeRegActive = 1 AND timeRegMFD = 0 ORDER BY timeRegID LIMIT 1',
      {'userId': userId, 'typeId': typeId, 'at': sqlDateTime(at)},
    );
    return rows.isEmpty ? null : rows.first.readInt('timeRegID');
  }

  /// The first active row of [userId] with [typeId] written after row
  /// [afterId] (the rounded row stored with an actual row), with its time.
  Future<({int id, DateTime at})?> nextOfType(SqlExecutor tx, int userId, int typeId, int afterId) async {
    final rows = await tx.query(
      'SELECT timeRegID, timeRegTimestamp FROM tblTimeReg '
      'WHERE userID = :userId AND timeRegTypeID = :typeId AND timeRegID > :afterId '
      'AND timeRegActive = 1 AND timeRegMFD = 0 ORDER BY timeRegID LIMIT 1',
      {'userId': userId, 'typeId': typeId, 'afterId': afterId},
    );
    if (rows.isEmpty) return null;
    final at = rows.first.readOptionalDateTime('timeRegTimestamp')!;
    return (id: rows.first.readInt('timeRegID'), at: DateTime.utc(at.year, at.month, at.day, at.hour, at.minute, at.second));
  }

  /// Adds an active row and returns its `timeRegID`. No address yet: where
  /// a registration happened comes with workplaces (phase 4).
  Future<int> insert(
    SqlExecutor tx, {
    required int userId,
    required int typeId,
    required DateTime at,
    required bool manualEntry,
    String? comment,
  }) async =>
      (await tx.execute(
        'INSERT INTO tblTimeReg (userID, addressID, timeRegTypeID, timeRegTimestamp, timeRegManualEntry, '
        'timeRegComment, timeRegWhenModified, timeRegActive, timeRegMFD) '
        'VALUES (:userId, NULL, :typeId, :at, :manual, :comment, NULL, 1, 0)',
        {'userId': userId, 'typeId': typeId, 'at': sqlDateTime(at), 'manual': manualEntry, 'comment': comment},
      ))
          .lastInsertId;

  /// [time] in UTC as MySQL `DATETIME` text, to the second.
  static String sqlDateTime(DateTime time) {
    final utc = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }
}
