import 'package:jitan_models/jitan_models.dart';

import '../database/like_pattern.dart';
import '../database/sql_executor.dart';

/// Data access for a company's employees: `tblUser` via `tblUserCompany`,
/// with groups from `tblUserGroup` → `tblGroup`.
///
/// Write methods take the [SqlExecutor] of the caller's transaction.
class EmployeeRepository {
  const EmployeeRepository(this._db);

  final SqlExecutor _db;

  /// Members of [companyId] with `userMFD = 0` (active and inactive),
  /// ordered by last name, first name.
  ///
  /// [nameOrCodeContains] matches first name, last name, "first last" or
  /// employee code; LIKE wildcards in it are matched literally.
  ///
  /// Groups: every active, non-MFD group of the user, by name. No group is
  /// singled out.
  Future<List<EmployeeSummary>> listForCompany(int companyId, {String? nameOrCodeContains}) =>
      _list(_db, companyId, nameOrCodeContains: nameOrCodeContains);

  /// One member of [companyId], or `null`.
  Future<EmployeeSummary?> findInCompany(SqlExecutor executor, int companyId, int userId) async =>
      (await _list(executor, companyId, userId: userId)).firstOrNull;

  /// Whether any user, in any company and including MFD users, has [code]
  /// (`tblUser.userCode` is unique across the table).
  Future<bool> codeExists(SqlExecutor executor, String code) async =>
      (await executor.query('SELECT 1 AS found FROM tblUser WHERE userCode = :code', {'code': code})).isNotEmpty;

  /// Inserts an active, non-MFD user and returns its `userID`. No password,
  /// PIN or email: those are set later (onboarding).
  Future<int> insertUser(
    SqlExecutor tx, {
    required String firstName,
    required String lastName,
    required String code,
    required String personalQrCode,
    required String? phone,
  }) async =>
      (await tx.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, cellphoneNumber, '
        'userKioskMode, userActive, userMFD) '
        'VALUES (:firstName, :lastName, :code, :qr, :phone, 0, 1, 0)',
        {'firstName': firstName, 'lastName': lastName, 'code': code, 'qr': personalQrCode, 'phone': phone},
      ))
          .lastInsertId;

  /// Links [userId] to [companyId]; returns the `userCompanyID`.
  Future<int> addToCompany(SqlExecutor tx, int userId, int companyId) async => (await tx.execute(
        'INSERT INTO tblUserCompany (userID, companyID) VALUES (:userId, :companyId)',
        {'userId': userId, 'companyId': companyId},
      ))
          .lastInsertId;

  /// Links [userId] to [groupId]; returns the `userGroupID`.
  Future<int> addToGroup(SqlExecutor tx, int userId, int groupId) async => (await tx.execute(
        'INSERT INTO tblUserGroup (userID, groupID) VALUES (:userId, :groupId)',
        {'userId': userId, 'groupId': groupId},
      ))
          .lastInsertId;

  Future<List<EmployeeSummary>> _list(
    SqlExecutor executor,
    int companyId, {
    String? nameOrCodeContains,
    int? userId,
  }) async {
    final searchFilter = nameOrCodeContains == null
        ? ''
        : 'AND (u.userName LIKE :pattern OR u.userSurname LIKE :pattern OR u.userCode LIKE :pattern '
            "OR CONCAT_WS(' ', u.userName, u.userSurname) LIKE :pattern) ";
    final userFilter = userId == null ? '' : 'AND u.userID = :userId ';
    final users = await executor.query(
      'SELECT u.userID, u.userName, u.userSurname, u.userCode, u.userActive '
      'FROM tblUser u JOIN tblUserCompany uc ON uc.userID = u.userID '
      'WHERE uc.companyID = :companyId AND u.userMFD = 0 '
      '$searchFilter'
      '$userFilter'
      'ORDER BY u.userSurname, u.userName, u.userID',
      {
        'companyId': companyId,
        if (nameOrCodeContains != null) 'pattern': containsLikePattern(nameOrCodeContains),
        'userId': ?userId,
      },
    );
    if (users.isEmpty) return const [];

    final groupRows = await executor.query(
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
