import '../database/db_row.dart';
import '../database/like_pattern.dart';
import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';

/// An employee row of the group page, before companies and groups are
/// attached.
typedef GroupMemberRow = ({int userId, String? firstName, String? lastName, String code});

/// Reads for the group page: a group's members and the employees that can be
/// added, from every company (groups are shared by all companies). Writes to
/// `tblUserGroup` go through EmployeeAssignmentRepository, the one place
/// that adds and removes group links.
class GroupMemberRepository {
  const GroupMemberRepository(this._executor);

  final SqlExecutor _executor;

  /// At most this many employees are offered at once; HR searches for more.
  static const candidateLimit = 50;

  /// Employees with a current link to [groupId] (non-deleted users).
  Future<List<GroupMemberRow>> members(int groupId) async => _rows(await _executor.query(
        'SELECT u.userID, u.userName, u.userSurname, u.userCode FROM tblUser u '
        'JOIN tblUserGroup ug ON ug.userID = u.userID AND ${MembershipFilters.activeGroup('ug')} '
        'WHERE ug.groupID = :groupId AND u.userMFD = 0 '
        'ORDER BY u.userSurname, u.userName, u.userID',
        {'groupId': groupId},
      ));

  /// Active employees of at least one active company who are not in
  /// [groupId], matching [search] on name or code when given.
  /// Without [groupId]: every such employee (Create group, before the group
  /// exists).
  Future<List<GroupMemberRow>> candidates(int? groupId, {String? search}) async {
    final searchFilter = search == null
        ? ''
        : 'AND (u.userName LIKE :pattern OR u.userSurname LIKE :pattern OR u.userCode LIKE :pattern '
            "OR CONCAT_WS(' ', u.userName, u.userSurname) LIKE :pattern) ";
    return _rows(await _executor.query(
      'SELECT u.userID, u.userName, u.userSurname, u.userCode FROM tblUser u '
      'WHERE u.userMFD = 0 AND u.userActive = 1 '
      'AND EXISTS (SELECT 1 FROM tblUserCompany uc JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID = u.userID AND ${MembershipFilters.activeCompany('uc')} AND c.companyMFD = 0) '
      '${groupId == null ? '' : 'AND NOT EXISTS (SELECT 1 FROM tblUserGroup ug WHERE ug.userID = u.userID '
          'AND ug.groupID = :groupId AND ${MembershipFilters.activeGroup('ug')}) '}'
      '$searchFilter'
      'ORDER BY u.userSurname, u.userName, u.userID '
      'LIMIT $candidateLimit',
      {'groupId': ?groupId, if (search != null) 'pattern': containsLikePattern(search)},
    ));
  }

  /// The current companies of [userIds]: `(companyID, companyName)` per user.
  Future<Map<int, List<(int, String)>>> companiesOf(List<int> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _executor.query(
      'SELECT uc.userID, c.companyID, c.companyName FROM tblUserCompany uc '
      'JOIN tblCompany c ON c.companyID = uc.companyID '
      'WHERE uc.userID IN (${userIds.join(',')}) AND ${MembershipFilters.activeCompany('uc')} AND c.companyMFD = 0 '
      'ORDER BY c.companyName, c.companyID',
    );
    final byUser = <int, List<(int, String)>>{};
    for (final row in rows) {
      byUser.putIfAbsent(row.readInt('userID'), () => []).add((row.readInt('companyID'), row.readString('companyName')));
    }
    return byUser;
  }

  /// The current, active groups of [userIds], by name.
  Future<Map<int, List<String>>> groupsOf(List<int> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _executor.query(
      'SELECT ug.userID, g.groupName FROM tblUserGroup ug JOIN tblGroup g ON g.groupID = ug.groupID '
      'WHERE ug.userID IN (${userIds.join(',')}) AND ${MembershipFilters.activeGroup('ug')} '
      'AND g.groupActive = 1 AND g.groupMFD = 0 '
      'ORDER BY g.groupName, g.groupID',
    );
    final byUser = <int, List<String>>{};
    for (final row in rows) {
      byUser.putIfAbsent(row.readInt('userID'), () => []).add(row.readString('groupName'));
    }
    return byUser;
  }

  /// Whether [groupId] exists and is not deleted; `null` when it does not,
  /// otherwise whether it is active.
  Future<bool?> groupIsActive(int groupId) async {
    final rows = await _executor.query(
      'SELECT groupActive FROM tblGroup WHERE groupID = :groupId AND groupMFD = 0',
      {'groupId': groupId},
    );
    return rows.isEmpty ? null : rows.single.readBool('groupActive');
  }

  static List<GroupMemberRow> _rows(List<DbRow> rows) => [
        for (final row in rows)
          (
            userId: row.readInt('userID'),
            firstName: row.readOptionalString('userName'),
            lastName: row.readOptionalString('userSurname'),
            code: row.readString('userCode'),
          ),
      ];
}
