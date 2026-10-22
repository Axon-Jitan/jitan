import '../database/sql_executor.dart';
import '../database/sql_in_list.dart';

/// One active `tblTimeReg` row with its type name, as Time records reads it.
typedef RegistrationRow = ({int id, int userId, String typeName, DateTime at, bool manualEntry, String? comment});

/// Reads registrations for Time records (TIME_ENGINE_ANALYSIS D4, D9, D14):
/// active, non-MFD rows only; timestamps are UTC.
class TimeRecordRepository {
  const TimeRecordRepository(this._db);

  final SqlExecutor _db;

  /// The registrations of [userIds] from [fromUtc] (inclusive) to [toUtc]
  /// (exclusive), oldest first.
  Future<List<RegistrationRow>> registrationsOf(List<int> userIds, DateTime fromUtc, DateTime toUtc) async {
    if (userIds.isEmpty) return const [];
    final users = SqlInList('u', userIds);
    final rows = await _db.query(
      'SELECT tr.timeRegID, tr.userID, t.timeRegTypeName, tr.timeRegTimestamp, tr.timeRegManualEntry, tr.timeRegComment '
      'FROM tblTimeReg tr JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID '
      'WHERE tr.userID IN (${users.placeholders}) AND tr.timeRegActive = 1 AND tr.timeRegMFD = 0 '
      'AND tr.timeRegTimestamp >= :from AND tr.timeRegTimestamp < :to '
      'ORDER BY tr.userID, tr.timeRegTimestamp, tr.timeRegID',
      {...users.params, 'from': _sql(fromUtc), 'to': _sql(toUtc)},
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
        ),
    ];
  }

  static String _sql(DateTime time) {
    final utc = time.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }
}
