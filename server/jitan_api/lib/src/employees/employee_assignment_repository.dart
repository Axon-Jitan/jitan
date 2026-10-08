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
