import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';

/// Data access for `tblGroup` (employee groupings, e.g. Blue/White collar).
class GroupRepository {
  const GroupRepository(this._db);

  final SqlExecutor _db;

  /// Groups that can be assigned: `groupActive = 1`, `groupMFD = 0`, by name.
  Future<List<GroupSummary>> listActive() async {
    final rows = await _db.query(
      'SELECT groupID, groupName FROM tblGroup WHERE groupActive = 1 AND groupMFD = 0 '
      'ORDER BY groupName, groupID',
    );
    return [
      for (final row in rows) GroupSummary(id: row.readInt('groupID'), name: row.readString('groupName')),
    ];
  }

  /// Whether [groupId] exists and can be assigned.
  Future<bool> isAssignable(int groupId) async {
    final rows = await _db.query(
      'SELECT 1 AS found FROM tblGroup WHERE groupID = :groupId AND groupActive = 1 AND groupMFD = 0',
      {'groupId': groupId},
    );
    return rows.isNotEmpty;
  }
}
