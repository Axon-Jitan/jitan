import 'package:jitan_models/jitan_models.dart';

import '../database/database.dart';
import '../database/db_row.dart';
import '../database/sql_executor.dart';
import '../database/like_pattern.dart';
import '../employees/membership_filters.dart';
import '../database/loose_text.dart';

/// Data access for `tblCompany` and the company list's derived columns.
class CompanyRepository {
  const CompanyRepository(this._db);

  final Database _db;

  /// Companies with `companyMFD = 0`, ordered by name.
  ///
  /// - Inactive companies are included: the list shows their status.
  /// - `employeeCount`: `tblUserCompany` memberships whose user is not MFD.
  /// - `lastUpdatedAt`: latest `tblEventLog.eventLogTimestamp` with this
  ///   `companyID`, or NULL.
  ///
  /// [nameContains] filters case-insensitively (per the column collation) on
  /// `companyName`; LIKE wildcards in it are matched literally.
  Future<List<CompanySummary>> listCompanies({String? nameContains}) async {
    final filter = nameContains == null ? '' : 'AND c.companyName $ignoringCaseAndAccents LIKE :namePattern ';
    final rows = await _db.query(
      'SELECT c.companyID, c.companyName, c.companyActive, '
      '(SELECT COUNT(*) FROM tblUserCompany uc '
      ' JOIN tblUser u ON u.userID = uc.userID '
      ' WHERE uc.companyID = c.companyID AND ${MembershipFilters.activeCompany('uc')} AND u.userMFD = 0) '
      'AS employeeCount, '
      '(SELECT MAX(e.eventLogTimestamp) FROM tblEventLog e '
      ' WHERE e.companyID = c.companyID) AS lastUpdatedAt '
      'FROM tblCompany c '
      'WHERE c.companyMFD = 0 '
      '$filter'
      'ORDER BY c.companyName, c.companyID',
      {if (nameContains != null) 'namePattern': containsLikePattern(nameContains)},
    );
    return rows.map(_toCompanySummary).toList();
  }

  /// Whether [companyId] exists and is not marked for deletion. Inactive
  /// companies count: their data stays viewable.
  Future<bool> exists(int companyId) async {
    final rows = await _db.query(
      'SELECT 1 AS found FROM tblCompany WHERE companyID = :companyId AND companyMFD = 0',
      {'companyId': companyId},
    );
    return rows.isNotEmpty;
  }

  /// One non-deleted company with its list columns, or `null`.
  Future<CompanySummary?> find(int companyId) async =>
      (await listCompanies()).where((c) => c.id == companyId).firstOrNull;

  /// Whether another non-deleted company has [name], ignoring capitals and
  /// accents (CLARIFY-16).
  Future<bool> nameTaken(SqlExecutor tx, String name, {int? exceptId}) async => (await tx.query(
    'SELECT 1 AS found FROM tblCompany WHERE companyMFD = 0 AND companyName $ignoringCaseAndAccents = :name '
    '${exceptId == null ? '' : 'AND companyID <> :except '}LIMIT 1',
    {'name': name, 'except': ?exceptId},
  )).isNotEmpty;

  /// A new, active company; its id.
  Future<int> insert(SqlExecutor tx, String name) async => (await tx.execute(
    'INSERT INTO tblCompany (companyName, companyActive, companyMFD) VALUES (:name, 1, 0)',
    {'name': name},
  )).lastInsertId;

  /// [companyId]'s name and whether it is active, locked for the
  /// transaction; `null` when unknown or deleted.
  Future<({String name, bool active})?> lock(SqlExecutor tx, int companyId) async {
    final rows = await tx.query(
      'SELECT companyName, companyActive FROM tblCompany WHERE companyID = :id AND companyMFD = 0 FOR UPDATE',
      {'id': companyId},
    );
    if (rows.isEmpty) return null;
    return (name: rows.single.readString('companyName'), active: rows.single.readBool('companyActive'));
  }

  Future<void> rename(SqlExecutor tx, int companyId, String name) =>
      tx.execute('UPDATE tblCompany SET companyName = :name WHERE companyID = :id', {'id': companyId, 'name': name});

  Future<void> setActive(SqlExecutor tx, int companyId, {required bool active}) => tx.execute(
    'UPDATE tblCompany SET companyActive = :active WHERE companyID = :id',
    {'id': companyId, 'active': active ? 1 : 0},
  );

  static CompanySummary _toCompanySummary(DbRow row) => CompanySummary(
        id: row.readInt('companyID'),
        name: row.readString('companyName'),
        isActive: row.readBool('companyActive'),
        employeeCount: row.readInt('employeeCount'),
        lastUpdatedAt: row.readOptionalDateTime('lastUpdatedAt'),
      );
}
