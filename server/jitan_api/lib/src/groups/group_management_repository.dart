import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';

/// Data access for HR/Admin managing employee groups (`tblGroup`). Writes
/// run in the caller's transaction. Groups are never deleted: deactivating
/// sets `groupActive = 0`, and the row stays.
class GroupManagementRepository {
  const GroupManagementRepository();

  /// Every non-MFD group, active or not, with the number of non-MFD
  /// employees currently in it, by name.
  Future<List<GroupOverview>> overview(SqlExecutor executor) async {
    final rows = await executor.query(
      'SELECT g.groupID, g.groupName, g.groupActive, '
      '(SELECT COUNT(*) FROM tblUserGroup ug JOIN tblUser u ON u.userID = ug.userID AND u.userMFD = 0 '
      ' WHERE ug.groupID = g.groupID AND ${MembershipFilters.activeGroup('ug')}) AS employeeCount '
      'FROM tblGroup g WHERE g.groupMFD = 0 ORDER BY g.groupName, g.groupID',
    );
    return [for (final row in rows) _toOverview(row)];
  }

  /// One non-MFD group, locked for the rest of the transaction; `null` when
  /// it does not exist or is marked for deletion.
  Future<GroupOverview?> lock(SqlExecutor tx, int groupId) async {
    final rows = await tx.query(
      'SELECT g.groupID, g.groupName, g.groupActive, 0 AS employeeCount FROM tblGroup g '
      'WHERE g.groupID = :id AND g.groupMFD = 0 FOR UPDATE',
      {'id': groupId},
    );
    if (rows.isEmpty) return null;
    return _toOverview(rows.single);
  }

  /// Whether another non-MFD group (active or not) has [name], ignoring
  /// upper/lower case. A locking read over the whole table: there is no
  /// unique key on `groupName`, so concurrent adds or renames of the same
  /// name wait for each other instead of both passing the check.
  Future<bool> nameTaken(SqlExecutor tx, String name, {int? exceptGroupId}) async => (await tx.query(
        'SELECT groupID FROM tblGroup WHERE groupMFD = 0 AND LOWER(groupName) = LOWER(:name) '
        '${exceptGroupId == null ? '' : 'AND groupID <> :except '}FOR UPDATE',
        {'name': name, 'except': ?exceptGroupId},
      ))
          .isNotEmpty;

  /// Non-MFD employees currently in [groupId].
  Future<int> employeeCount(SqlExecutor tx, int groupId) async => (await tx.query(
        'SELECT COUNT(*) AS n FROM tblUserGroup ug JOIN tblUser u ON u.userID = ug.userID AND u.userMFD = 0 '
        'WHERE ug.groupID = :id AND ${MembershipFilters.activeGroup('ug')}',
        {'id': groupId},
      ))
          .single
          .readInt('n');

  Future<int> insert(SqlExecutor tx, String name) async => (await tx.execute(
        'INSERT INTO tblGroup (groupName, groupActive, groupMFD) VALUES (:name, 1, 0)',
        {'name': name},
      ))
          .lastInsertId;

  Future<void> rename(SqlExecutor tx, int groupId, String name) =>
      tx.execute('UPDATE tblGroup SET groupName = :name WHERE groupID = :id', {'name': name, 'id': groupId});

  Future<void> setActive(SqlExecutor tx, int groupId, {required bool active}) =>
      tx.execute('UPDATE tblGroup SET groupActive = :active WHERE groupID = :id', {'active': active, 'id': groupId});

  static GroupOverview _toOverview(DbRow row) => GroupOverview(
        id: row.readInt('groupID'),
        name: row.readString('groupName'),
        isActive: row.readBool('groupActive'),
        employeeCount: row.readInt('employeeCount'),
      );
}
