import 'package:jitan_models/jitan_models.dart';

import '../database/database.dart';
import '../database/like_pattern.dart';

/// Data access for a company's employees: `tblUser` via `tblUserCompany`,
/// with groups from `tblUserGroup` → `tblGroup`.
class EmployeeRepository {
  const EmployeeRepository(this._db);

  final Database _db;

  /// Members of [companyId] with `userMFD = 0` (active and inactive),
  /// ordered by last name, first name.
  ///
  /// [nameOrCodeContains] matches first name, last name, "first last" or
  /// employee code; LIKE wildcards in it are matched literally.
  ///
  /// Groups: every active, non-MFD group of the user, by name. No group is
  /// singled out.
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? nameOrCodeContains}) async {
    final filter = nameOrCodeContains == null
        ? ''
        : 'AND (u.userName LIKE :pattern OR u.userSurname LIKE :pattern OR u.userCode LIKE :pattern '
            "OR CONCAT_WS(' ', u.userName, u.userSurname) LIKE :pattern) ";
    final users = await _db.query(
      'SELECT u.userID, u.userName, u.userSurname, u.userCode, u.userActive '
      'FROM tblUser u JOIN tblUserCompany uc ON uc.userID = u.userID '
      'WHERE uc.companyID = :companyId AND u.userMFD = 0 '
      '$filter'
      'ORDER BY u.userSurname, u.userName, u.userID',
      {
        'companyId': companyId,
        if (nameOrCodeContains != null) 'pattern': containsLikePattern(nameOrCodeContains),
      },
    );
    if (users.isEmpty) return const [];

    final groupRows = await _db.query(
      'SELECT ug.userID, g.groupName FROM tblUserGroup ug '
      'JOIN tblGroup g ON g.groupID = ug.groupID '
      'JOIN tblUserCompany uc ON uc.userID = ug.userID '
      'WHERE uc.companyID = :companyId AND g.groupActive = 1 AND g.groupMFD = 0 '
      'ORDER BY g.groupName, g.groupID',
      {'companyId': companyId},
    );
    final groupsByUser = <int, List<String>>{};
    for (final row in groupRows) {
      groupsByUser.putIfAbsent(row.readInt('userID'), () => []).add(row.readString('groupName'));
    }

    return [
      for (final row in users)
        EmployeeSummary(
          id: row.readInt('userID'),
          firstName: row.readOptionalString('userName'),
          lastName: row.readOptionalString('userSurname'),
          code: row.readString('userCode'),
          groups: groupsByUser[row.readInt('userID')] ?? const [],
          isActive: row.readBool('userActive'),
        ),
    ];
  }
}
