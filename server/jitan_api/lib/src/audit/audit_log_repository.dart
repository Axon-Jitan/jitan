import 'package:logging/logging.dart';

import '../database/sql_executor.dart';
import 'audit_event.dart';

final _log = Logger('audit');

/// Writes audit events to `tblEventLog` (+ `tblEventLogEventType`).
///
/// Always called with the executor of the transaction that made the change,
/// so the change and its audit row commit or roll back together.
class AuditLogRepository {
  const AuditLogRepository();

  Future<void> record(SqlExecutor tx, AuditEvent event) async {
    final columns = ['eventLogTimestamp', 'userIDInit', for (final r in event.references.keys) r.column];
    final values = ['NOW()', ':actor', for (final r in event.references.keys) ':${r.name}'];
    final logId = (await tx.execute(
      'INSERT INTO tblEventLog (${columns.join(', ')}) VALUES (${values.join(', ')})',
      {
        'actor': event.actorUserId,
        for (final MapEntry(:key, :value) in event.references.entries) key.name: value,
      },
    ))
        .lastInsertId;

    final typeRows = await tx.query(
      'SELECT eventTypeID FROM tblEventType WHERE eventTypeName = :name',
      {'name': event.type.typeName},
    );
    if (typeRows.isEmpty) {
      _log.warning('tblEventType has no row named "${event.type.typeName}" (CLARIFY-11); '
          'tblEventLog $logId is stored without an event type.');
      return;
    }
    await tx.execute(
      'INSERT INTO tblEventLogEventType (eventTypeID, eventLogID) VALUES (:typeId, :logId)',
      {'typeId': typeRows.first.readInt('eventTypeID'), 'logId': logId},
    );
  }
}
