import 'package:jitan_models/jitan_models.dart';

import '../database/database_exception.dart';
import '../database/sql_executor.dart';
import 'membership_filters.dart';

/// One link table with Active/MFD: how its columns are named.
class _SoftLink {
  const _SoftLink(this.table, this.id, this.other, this.active, this.mfd);

  final String table;
  final String id;
  final String other;
  final String active;
  final String mfd;
}

const _companyLink = _SoftLink('tblUserCompany', 'userCompanyID', 'companyID', 'userCompanyActive', 'userCompanyMFD');
const _groupLink = _SoftLink('tblUserGroup', 'userGroupID', 'groupID', 'userGroupActive', 'userGroupMFD');

/// Data access for "Manage employee assignments": the employee's links in
/// the ERD's junction tables.
///
/// `tblUserCompany` and `tblUserGroup` have Active/MFD (IT decision
/// 2026-10-08): removing sets `Active = 0, MFD = 1` and keeps the row;
/// adding again reactivates that row (the unique pair allows one row per
/// pair). No row is ever deleted. `tblUserCredGroup` has no Active/MFD and
/// is only added to (CLARIFY-09).
class EmployeeAssignmentRepository {
  const EmployeeAssignmentRepository();

  /// MySQL duplicate-key error: the pair already exists (unique pair).
  static const _duplicateKey = 1062;

  // ── Companies (tblUserCompany) ─────────────────────────────────────────

  /// Every non-MFD company that is active or that [userId] currently belongs
  /// to, with the membership flag, ordered by name. Removed memberships do
  /// not count.
  Future<List<AssignmentOption>> companyOptions(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT c.companyID, c.companyName, c.companyActive, '
      '(uc.userCompanyID IS NOT NULL) AS isAssigned '
      'FROM tblCompany c '
      'LEFT JOIN tblUserCompany uc ON uc.companyID = c.companyID AND uc.userID = :userId '
      'AND ${MembershipFilters.activeCompany('uc')} '
      'WHERE c.companyMFD = 0 AND (c.companyActive = 1 OR uc.userCompanyID IS NOT NULL) '
      'ORDER BY c.companyName, c.companyID',
      {'userId': userId},
    );
    return [
      for (final row in rows)
        AssignmentOption(
          id: row.readInt('companyID'),
          name: row.readOptionalString('companyName') ?? '',
          isActive: row.readBool('companyActive'),
          isAssigned: row.readBool('isAssigned'),
        ),
    ];
  }

  /// Makes [userId] a member of [companyId]: inserts the pair, or
  /// reactivates a removed one. Returns the `userCompanyID` when something
  /// changed, `null` when the membership was already current.
  Future<int?> addCompany(SqlExecutor tx, int userId, int companyId) => _activate(tx, _companyLink, userId, companyId);

  /// Soft-removes the current membership; returns its `userCompanyID`, or
  /// `null` when there was none.
  Future<int?> removeCompany(SqlExecutor tx, int userId, int companyId) =>
      _deactivate(tx, _companyLink, userId, companyId);

  // ── Groups (tblUserGroup) ────────────────────────────────────────────

  /// Every non-MFD group that is active or currently assigned to [userId].
  /// Groups are universal: the same for every company (IT, 2026-10-08).
  Future<List<AssignmentOption>> groupOptions(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT g.groupID, g.groupName, g.groupActive, (ug.userGroupID IS NOT NULL) AS isAssigned '
      'FROM tblGroup g '
      'LEFT JOIN tblUserGroup ug ON ug.groupID = g.groupID AND ug.userID = :userId '
      'AND ${MembershipFilters.activeGroup('ug')} '
      'WHERE g.groupMFD = 0 AND (g.groupActive = 1 OR ug.userGroupID IS NOT NULL) '
      'ORDER BY g.groupName, g.groupID',
      {'userId': userId},
    );
    return [
      for (final row in rows)
        AssignmentOption(
          id: row.readInt('groupID'),
          name: row.readOptionalString('groupName') ?? '',
          isActive: row.readBool('groupActive'),
          isAssigned: row.readBool('isAssigned'),
        ),
    ];
  }

  /// Assigns [groupId] (insert or reactivate); the `userGroupID` when
  /// something changed, `null` when it was already assigned.
  Future<int?> addGroup(SqlExecutor tx, int userId, int groupId) => _activate(tx, _groupLink, userId, groupId);

  /// Soft-removes the group assignment; its `userGroupID`, or `null` when
  /// there was none.
  Future<int?> removeGroup(SqlExecutor tx, int userId, int groupId) => _deactivate(tx, _groupLink, userId, groupId);

  // ── Credential groups (tblUserCredGroup) ─────────────────────────────

  /// Every non-MFD credential group that is active or already assigned to
  /// [userId], in `credGroupLevel` order. Names come from the database; no
  /// role name is assumed.
  Future<List<AssignmentOption>> credentialGroupOptions(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT cg.credGroupID, cg.credGroupName, cg.credGroupActive, (ucg.userCredGroupID IS NOT NULL) AS isAssigned '
      'FROM tblCredGroup cg '
      'LEFT JOIN tblUserCredGroup ucg ON ucg.credGroupID = cg.credGroupID AND ucg.userID = :userId '
      'WHERE cg.credGroupMFD = 0 AND (cg.credGroupActive = 1 OR ucg.userCredGroupID IS NOT NULL) '
      'ORDER BY cg.credGroupLevel, cg.credGroupName, cg.credGroupID',
      {'userId': userId},
    );
    return [
      for (final row in rows)
        AssignmentOption(
          id: row.readInt('credGroupID'),
          name: row.readOptionalString('credGroupName') ?? '',
          isActive: row.readBool('credGroupActive'),
          isAssigned: row.readBool('isAssigned'),
        ),
    ];
  }

  /// Links [userId] to [credGroupId] in `tblUserCredGroup`; the new
  /// `userCredGroupID`, or `null` when the pair already exists.
  Future<int?> addCredentialGroup(SqlExecutor tx, int userId, int credGroupId) => _insertPair(
        tx,
        'INSERT INTO tblUserCredGroup (userID, credGroupID) '
        'SELECT :userId, :otherId FROM DUAL WHERE NOT EXISTS '
        '(SELECT 1 FROM tblUserCredGroup WHERE userID = :userId AND credGroupID = :otherId)',
        userId,
        credGroupId,
      );

  /// The active, non-MFD credential groups [userId] holds.
  Future<Set<int>> heldCredentialGroupIds(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT cg.credGroupID FROM tblUserCredGroup ucg JOIN tblCredGroup cg ON cg.credGroupID = ucg.credGroupID '
      'WHERE ucg.userID = :userId AND cg.credGroupActive = 1 AND cg.credGroupMFD = 0',
      {'userId': userId},
    );
    return {for (final row in rows) row.readInt('credGroupID')};
  }

  /// Every non-MFD company [userId] currently belongs to (active or not):
  /// where a user-wide credential group takes effect.
  Future<List<int>> memberCompanyIds(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT c.companyID FROM tblUserCompany uc JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID = :userId AND ${MembershipFilters.activeCompany('uc')} AND c.companyMFD = 0 '
      'ORDER BY c.companyID',
      {'userId': userId},
    );
    return [for (final row in rows) row.readInt('companyID')];
  }

  /// Insert the pair, or reactivate its removed row. Callers hold the
  /// employee's row lock, so the read and the write cannot interleave with
  /// another change of this employee; the unique pair is the last guard.
  Future<int?> _activate(SqlExecutor tx, _SoftLink link, int userId, int otherId) async {
    final rows = await tx.query(
      'SELECT ${link.id} AS id, (${link.active} = 1 AND ${link.mfd} = 0) AS current '
      'FROM ${link.table} WHERE userID = :userId AND ${link.other} = :otherId',
      {'userId': userId, 'otherId': otherId},
    );
    if (rows.isEmpty) {
      try {
        return (await tx.execute(
          'INSERT INTO ${link.table} (userID, ${link.other}, ${link.active}, ${link.mfd}) '
          'VALUES (:userId, :otherId, 1, 0)',
          {'userId': userId, 'otherId': otherId},
        )).lastInsertId;
      } on DatabaseQueryException catch (e) {
        if (e.errorCode == _duplicateKey) return null;
        rethrow;
      }
    }
    final row = rows.single;
    if (row.readOptionalBool('current') ?? false) return null;
    final id = row.readInt('id');
    await tx.execute('UPDATE ${link.table} SET ${link.active} = 1, ${link.mfd} = 0 WHERE ${link.id} = :id', {'id': id});
    return id;
  }

  /// Soft delete: `Active = 0, MFD = 1`; the row stays.
  Future<int?> _deactivate(SqlExecutor tx, _SoftLink link, int userId, int otherId) async {
    final rows = await tx.query(
      'SELECT ${link.id} AS id FROM ${link.table} '
      'WHERE userID = :userId AND ${link.other} = :otherId AND ${link.active} = 1 AND ${link.mfd} = 0',
      {'userId': userId, 'otherId': otherId},
    );
    if (rows.isEmpty) return null;
    final id = rows.single.readInt('id');
    await tx.execute('UPDATE ${link.table} SET ${link.active} = 0, ${link.mfd} = 1 WHERE ${link.id} = :id', {'id': id});
    return id;
  }

  /// Inserts a junction pair unless it exists; `null` when it did.
  Future<int?> _insertPair(SqlExecutor tx, String sql, int userId, int otherId) async {
    try {
      final result = await tx.execute(sql, {'userId': userId, 'otherId': otherId});
      return result.affectedRows == 1 ? result.lastInsertId : null;
    } on DatabaseQueryException catch (e) {
      // The unique pair caught a concurrent insert of the same pair.
      if (e.errorCode == _duplicateKey) return null;
      rethrow;
    }
  }
}
