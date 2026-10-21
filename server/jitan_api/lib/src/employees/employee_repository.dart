import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/like_pattern.dart';
import '../database/sql_in_list.dart';
import '../database/sql_executor.dart';
import 'membership_filters.dart';

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
      _list(_db, [companyId], nameOrCodeContains: nameOrCodeContains);

  /// Members of any of [companyIds], each once, with the companies of
  /// [companyIds] they belong to; otherwise as [listForCompany].
  Future<List<EmployeeSummary>> listForCompanies(List<int> companyIds, {String? nameOrCodeContains}) async =>
      companyIds.isEmpty ? const [] : _list(_db, companyIds, nameOrCodeContains: nameOrCodeContains);

  /// One member of [companyId], or `null`.
  /// Locks [userId]'s `tblUser` row until the transaction ends, so changes
  /// to one user's relationships run one after the other. `false` when the
  /// user does not exist.
  Future<bool> lockUser(SqlExecutor tx, int userId) async =>
      (await tx.query('SELECT userID FROM tblUser WHERE userID = :userId FOR UPDATE', {'userId': userId})).isNotEmpty;

  Future<EmployeeSummary?> findInCompany(SqlExecutor executor, int companyId, int userId) async =>
      (await _list(executor, [companyId], userId: userId)).firstOrNull;

  /// Details of [userId] as a non-MFD member of [companyId], or `null`.
  Future<EmployeeDetails?> findDetails(int companyId, int userId) async {
    final rows = await _db.query(
      'SELECT u.userID, u.userName, u.userSurname, u.userCode, u.cellphoneNumber, u.userActive, '
      '(u.userPassword IS NOT NULL) AS isActivated, c.companyID, c.companyName '
      'FROM tblUser u '
      'JOIN tblUserCompany uc ON uc.userID = u.userID AND ${MembershipFilters.activeCompany('uc')} '
      'JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.companyID = :companyId AND u.userID = :userId AND u.userMFD = 0 AND c.companyMFD = 0',
      {'companyId': companyId, 'userId': userId},
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final groups = await _db.query(
      'SELECT g.groupName FROM tblUserGroup ug JOIN tblGroup g ON g.groupID = ug.groupID '
      'WHERE ug.userID = :userId AND ${MembershipFilters.activeGroup('ug')} AND g.groupActive = 1 AND g.groupMFD = 0 '
      'ORDER BY g.groupName, g.groupID',
      {'userId': userId},
    );
    return EmployeeDetails(
      id: row.readInt('userID'),
      companyId: row.readInt('companyID'),
      companyName: row.readString('companyName'),
      firstName: row.readOptionalString('userName'),
      lastName: row.readOptionalString('userSurname'),
      code: row.readString('userCode'),
      groups: [for (final g in groups) g.readString('groupName')],
      phone: row.readOptionalString('cellphoneNumber'),
      isActive: row.readBool('userActive'),
      isActivated: row.readBool('isActivated'),
    );
  }

  /// Whether any user, in any company and including MFD users, has [code]
  /// (`tblUser.userCode` is unique across the table).
  Future<bool> codeExists(SqlExecutor executor, String code) async =>
      (await executor.query('SELECT 1 AS found FROM tblUser WHERE userCode = :code', {'code': code})).isNotEmpty;

  /// Which of [codes] some user already has, in any company and including
  /// MFD users, as stored (`tblUser.userCode` is unique; MySQL compares it
  /// without regard to case). Reads through [executor] (a transaction) when
  /// given.
  Future<List<String>> existingCodes(Iterable<String> codes, {SqlExecutor? executor}) async {
    if (codes.isEmpty) return const [];
    final list = SqlInList('c', codes);
    final rows = await (executor ?? _db).query('SELECT userCode FROM tblUser WHERE userCode IN (${list.placeholders})', list.params);
    return [for (final row in rows) row.readString('userCode')];
  }

  /// Inserts an active, non-MFD user and returns its `userID`. No password:
  /// the employee sets it during onboarding (`userPassword IS NULL` until then).
  Future<int> insertUser(
    SqlExecutor tx, {
    required String firstName,
    required String lastName,
    required String code,
    required String personalQrCode,
    required String? phone,
    String? email,
  }) async =>
      (await tx.execute(
        'INSERT INTO tblUser (userName, userSurname, userCode, userQRcode, cellphoneNumber, userEmail, '
        'userKioskMode, userActive, userMFD) '
        'VALUES (:firstName, :lastName, :code, :qr, :phone, :email, 0, 1, 0)',
        {'firstName': firstName, 'lastName': lastName, 'code': code, 'qr': personalQrCode, 'phone': phone, 'email': email},
      ))
          .lastInsertId;

  /// Marks [userId] for deletion (`userMFD = 1`): hidden from every list,
  /// refused at sign-in; the row and everything that refers to it stay.
  /// `false` when the user was already marked.
  Future<bool> markRemoved(SqlExecutor tx, int userId) async =>
      (await tx.execute('UPDATE tblUser SET userMFD = 1 WHERE userID = :userId AND userMFD = 0', {'userId': userId}))
          .affectedRows ==
      1;

  /// Links [userId] to [companyId]; returns the `userCompanyID`.
  Future<int> addToCompany(SqlExecutor tx, int userId, int companyId) async => (await tx.execute(
        'INSERT INTO tblUserCompany (userID, companyID, userCompanyActive, userCompanyMFD) '
        'VALUES (:userId, :companyId, 1, 0)',
        {'userId': userId, 'companyId': companyId},
      ))
          .lastInsertId;

  /// Links [userId] to [groupId]; returns the `userGroupID`.
  Future<int> addToGroup(SqlExecutor tx, int userId, int groupId) async => (await tx.execute(
        'INSERT INTO tblUserGroup (userID, groupID, userGroupActive, userGroupMFD) VALUES (:userId, :groupId, 1, 0)',
        {'userId': userId, 'groupId': groupId},
      ))
          .lastInsertId;

  Future<List<EmployeeSummary>> _list(
    SqlExecutor executor,
    List<int> companyIds, {
    String? nameOrCodeContains,
    int? userId,
  }) async {
    final companies = SqlInList('co', companyIds);
    final searchFilter = nameOrCodeContains == null
        ? ''
        : 'AND (u.userName LIKE :pattern OR u.userSurname LIKE :pattern OR u.userCode LIKE :pattern '
            "OR CONCAT_WS(' ', u.userName, u.userSurname) LIKE :pattern) ";
    final userFilter = userId == null ? '' : 'AND u.userID = :userId ';
    // One row per membership; an employee of several listed companies is
    // merged below.
    final memberships = await executor.query(
      'SELECT u.userID, u.userName, u.userSurname, u.userCode, u.userActive, '
      '(u.userPassword IS NOT NULL) AS isActivated, uc.companyID '
      'FROM tblUser u JOIN tblUserCompany uc ON uc.userID = u.userID AND ${MembershipFilters.activeCompany('uc')} '
      'WHERE uc.companyID IN (${companies.placeholders}) AND u.userMFD = 0 '
      '$searchFilter'
      '$userFilter'
      'ORDER BY u.userSurname, u.userName, u.userID, uc.companyID',
      {
        ...companies.params,
        if (nameOrCodeContains != null) 'pattern': containsLikePattern(nameOrCodeContains),
        'userId': ?userId,
      },
    );
    if (memberships.isEmpty) return const [];

    final groupRows = await executor.query(
      'SELECT DISTINCT ug.userID, g.groupID, g.groupName FROM tblUserGroup ug '
      'JOIN tblGroup g ON g.groupID = ug.groupID '
      'JOIN tblUserCompany uc ON uc.userID = ug.userID AND ${MembershipFilters.activeCompany('uc')} '
      'WHERE uc.companyID IN (${companies.placeholders}) AND ${MembershipFilters.activeGroup('ug')} '
      'AND g.groupActive = 1 AND g.groupMFD = 0 '
      'ORDER BY g.groupName, g.groupID',
      companies.params,
    );
    final groupsByUser = <int, List<String>>{};
    for (final row in groupRows) {
      groupsByUser.putIfAbsent(row.readInt('userID'), () => []).add(row.readString('groupName'));
    }

    final companiesByUser = <int, List<int>>{};
    final firstRow = <int, DbRow>{};
    for (final row in memberships) {
      final id = row.readInt('userID');
      firstRow.putIfAbsent(id, () => row);
      companiesByUser.putIfAbsent(id, () => []).add(row.readInt('companyID'));
    }
    return [
      for (final MapEntry(key: id, value: row) in firstRow.entries)
        EmployeeSummary(
          id: id,
          firstName: row.readOptionalString('userName'),
          lastName: row.readOptionalString('userSurname'),
          code: row.readString('userCode'),
          groups: groupsByUser[id] ?? const [],
          isActive: row.readBool('userActive'),
          isActivated: row.readBool('isActivated'),
          companyIds: companiesByUser[id]!,
        ),
    ];
  }
}
