import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/sql_executor.dart';

/// Where a page continues: after this (timestamp, id).
typedef TimeRegistrationPosition = ({DateTime timestamp, int id});

/// Read-only data access for `tblTimeReg`. Writing (detection, manual
/// entries, corrections) waits for GAP-01 and CLARIFY-02.
class TimeRegistrationRepository {
  const TimeRegistrationRepository(this._db);

  final SqlExecutor _db;

  /// Active, non-MFD registrations of [userId] with
  /// `from <= timeRegTimestamp < to`, after [after] when given, oldest first
  /// (timestamp, then id, so equal timestamps page stably). At most [limit]
  /// rows. Times are wall-clock values compared as stored (GAP-02).
  ///
  /// Type and address are joined for their names only; a registration is
  /// returned even when its type or address has since been deactivated.
  Future<List<TimeRegistration>> listForUser(
    int userId, {
    required DateTime from,
    required DateTime to,
    required int limit,
    TimeRegistrationPosition? after,
  }) async {
    final rows = await _db.query(
      'SELECT tr.timeRegID, tr.userID, tr.timeRegTimestamp, tr.timeRegManualEntry, tr.timeRegComment, '
      'tr.timeRegWhenModified, t.timeRegTypeID, t.timeRegTypeName, a.addressID, a.addressLogicalName '
      'FROM tblTimeReg tr '
      'LEFT JOIN tblTimeRegType t ON t.timeRegTypeID = tr.timeRegTypeID '
      'LEFT JOIN tblAddress a ON a.addressID = tr.addressID '
      'WHERE tr.userID = :userId AND tr.timeRegActive = 1 AND tr.timeRegMFD = 0 '
      'AND tr.timeRegTimestamp >= :from AND tr.timeRegTimestamp < :to '
      '${after == null ? '' : 'AND (tr.timeRegTimestamp > :afterTs OR (tr.timeRegTimestamp = :afterTs AND tr.timeRegID > :afterId)) '}'
      'ORDER BY tr.timeRegTimestamp, tr.timeRegID '
      'LIMIT ${limit.clamp(1, 10000)}',
      {
        'userId': userId,
        'from': _sql(from),
        'to': _sql(to),
        if (after != null) ...{'afterTs': _sql(after.timestamp), 'afterId': after.id},
      },
    );
    return rows.map(_toRegistration).toList();
  }

  /// A wall-clock value as a MySQL DATETIME literal.
  static String _sql(DateTime value) => value.toIso8601String().replaceFirst('T', ' ');

  static TimeRegistration _toRegistration(DbRow row) => TimeRegistration(
        id: row.readInt('timeRegID'),
        userId: row.readInt('userID'),
        timestamp: row.readOptionalDateTime('timeRegTimestamp')!,
        typeId: row.readOptionalInt('timeRegTypeID'),
        typeName: row.readOptionalString('timeRegTypeName'),
        addressId: row.readOptionalInt('addressID'),
        addressName: row.readOptionalString('addressLogicalName'),
        isManualEntry: row.readOptionalBool('timeRegManualEntry'),
        comment: row.readOptionalString('timeRegComment'),
        modifiedAt: row.readOptionalDateTime('timeRegWhenModified'),
      );
}
