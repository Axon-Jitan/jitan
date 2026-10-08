import 'package:jitan_models/jitan_models.dart';

import '../database/database_exception.dart';
import '../database/sql_executor.dart';

/// Data access for "Manage employee assignments": the employee's links in
/// the ERD's junction tables. Only adds: removing a junction row waits for
/// IT (ERD.md, Active + MFD lifecycle).
class EmployeeAssignmentRepository {
  const EmployeeAssignmentRepository();

  /// MySQL duplicate-key error: the pair already exists (unique pair).
  static const _duplicateKey = 1062;

  // ── Companies (tblUserCompany) ─────────────────────────────────────────

  /// Every non-MFD company that is active or that [userId] already belongs
  /// to, with the membership flag, ordered by name.
  Future<List<AssignmentOption>> companyOptions(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT c.companyID, c.companyName, c.companyActive, '
      '(uc.userCompanyID IS NOT NULL) AS isAssigned '
      'FROM tblCompany c '
      'LEFT JOIN tblUserCompany uc ON uc.companyID = c.companyID AND uc.userID = :userId '
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

  /// Links [userId] to [companyId] in `tblUserCompany`. Returns the new
  /// `userCompanyID`, or `null` when the pair already exists (also when a
  /// concurrent request added it first): duplicates are never created.
  Future<int?> addCompany(SqlExecutor tx, int userId, int companyId) => _insertPair(
        tx,
        'INSERT INTO tblUserCompany (userID, companyID) '
        'SELECT :userId, :otherId FROM DUAL WHERE NOT EXISTS '
        '(SELECT 1 FROM tblUserCompany WHERE userID = :userId AND companyID = :otherId)',
        userId,
        companyId,
      );

  // ── Groups (tblUserGroup) ────────────────────────────────────────────

  /// Every non-MFD group that is active or already assigned to [userId].
  /// Groups are universal: the same for every company (IT, 2026-10-08).
  Future<List<AssignmentOption>> groupOptions(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT g.groupID, g.groupName, g.groupActive, (ug.userGroupID IS NOT NULL) AS isAssigned '
      'FROM tblGroup g '
      'LEFT JOIN tblUserGroup ug ON ug.groupID = g.groupID AND ug.userID = :userId '
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

  /// Links [userId] to [groupId] in `tblUserGroup`; the new `userGroupID`, or
  /// `null` when the pair already exists.
  Future<int?> addGroup(SqlExecutor tx, int userId, int groupId) => _insertPair(
        tx,
        'INSERT INTO tblUserGroup (userID, groupID) '
        'SELECT :userId, :otherId FROM DUAL WHERE NOT EXISTS '
        '(SELECT 1 FROM tblUserGroup WHERE userID = :userId AND groupID = :otherId)',
        userId,
        groupId,
      );

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

  /// Every non-MFD company [userId] belongs to (active or not): the
  /// employee's current company (one in the MVP), and where a user-wide
  /// credential group takes effect.
  Future<List<int>> memberCompanyIds(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT c.companyID FROM tblUserCompany uc JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID = :userId AND c.companyMFD = 0 ORDER BY c.companyID',
      {'userId': userId},
    );
    return [for (final row in rows) row.readInt('companyID')];
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
