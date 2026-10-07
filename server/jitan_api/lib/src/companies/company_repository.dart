import 'package:jitan_models/jitan_models.dart';

import '../database/database.dart';
import '../database/db_row.dart';
import '../database/like_pattern.dart';

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
    final filter = nameContains == null ? '' : 'AND c.companyName LIKE :namePattern ';
    final rows = await _db.query(
      'SELECT c.companyID, c.companyName, c.companyActive, '
      '(SELECT COUNT(*) FROM tblUserCompany uc '
      ' JOIN tblUser u ON u.userID = uc.userID '
      ' WHERE uc.companyID = c.companyID AND u.userMFD = 0) AS employeeCount, '
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

  static CompanySummary _toCompanySummary(DbRow row) => CompanySummary(
        id: row.readInt('companyID'),
        name: row.readString('companyName'),
        isActive: row.readBool('companyActive'),
        employeeCount: row.readInt('employeeCount'),
        lastUpdatedAt: row.readOptionalDateTime('lastUpdatedAt'),
      );
}
