import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';
import '../time_records/time_record_repository.dart';

/// One activity row of `tblTimeReg`.
typedef ActivityRow = ({
  int id,
  String typeName,
  DateTime at,
  int? projectId,
  int? companyId,
  // Where it happened, when that is known (D40).
  int? addressId,
  // The address of the project.
  int? projectAddressId,
});

/// A project with what the employee's history says about it.
typedef AssignedProject = ({MyProject project, DateTime? lastUsed, int? addressId});

/// Data access for activities (D19, D22, D37). PROPOSAL
/// (docs/database/PROPOSED_TABLES.md): uses tables and columns that exist only
/// in the local database, so nothing here runs where they are missing. The
/// Start and Finish rows are not touched: an activity is a row of its own.
class ActivityRepository {
  const ActivityRepository();

  /// `tblTimeRegType` names of activities start with this.
  static const typePrefix = 'Activity – ';
  static const transportType = '${typePrefix}Transport';

  static const _clientType = 'Client';
  static const _finishedStatus = 'Completed';

  /// Whether this database has the proposed tables.
  Future<bool> available(SqlExecutor executor) async => (await executor.query(
    'SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() '
    "AND TABLE_NAME = 'tblTimeReg' AND COLUMN_NAME = 'projectID'",
  )).isNotEmpty;

  /// The active projects [userId] has worked on or is assigned to, newest
  /// use first.
  Future<List<AssignedProject>> projects(SqlExecutor executor, int userId) async {
    final rows = await executor.query(
      'SELECT p.projectID, p.projectName, p.companyID, p.addressID, c.companyName, t.projectTypeName, s.projectStatusName, '
      '(up.userProjectActive = 1 AND up.userProjectMFD = 0) AS assigned, '
      '(SELECT MAX(r.timeRegTimestamp) FROM tblTimeReg r WHERE r.userID = up.userID '
      ' AND r.projectID = p.projectID AND r.timeRegActive = 1 AND r.timeRegMFD = 0) AS lastUsed '
      'FROM tblUserProject up '
      'JOIN tblProject p ON p.projectID = up.projectID AND p.projectActive = 1 AND p.projectMFD = 0 '
      'JOIN tblCompany c ON c.companyID = p.companyID '
      'JOIN tblProjectType t ON t.projectTypeID = p.projectTypeID '
      'JOIN tblProjectStatus s ON s.projectStatusID = p.projectStatusID '
      'WHERE up.userID = :user ORDER BY lastUsed DESC, p.projectName, p.projectID',
      {'user': userId},
    );
    return [
      for (final row in rows)
        (
          project: MyProject(
            id: row.readInt('projectID'),
            name: row.readString('projectName'),
            companyId: row.readInt('companyID'),
            companyName: row.readString('companyName'),
            isClient: row.readString('projectTypeName') == _clientType,
            isCurrent: row.readBool('assigned') && row.readString('projectStatusName') != _finishedStatus,
          ),
          lastUsed: row.readOptionalString('lastUsed') == null ? null : row.readUtcDateTime('lastUsed'),
          addressId: row.readOptionalInt('addressID'),
        ),
    ];
  }

  /// The active companies of [userId], by name.
  Future<List<MyCompany>> companies(SqlExecutor executor, int userId) async => [
    for (final row in await executor.query(
      'SELECT c.companyID, c.companyName, uc.userCompanyDefault FROM tblUserCompany uc '
      'JOIN tblCompany c ON c.companyID = uc.companyID AND c.companyActive = 1 AND c.companyMFD = 0 '
      'WHERE uc.userID = :user AND ${MembershipFilters.activeCompany('uc')} ORDER BY c.companyName, c.companyID',
      {'user': userId},
    ))
      MyCompany(
        id: row.readInt('companyID'),
        name: row.readString('companyName'),
        isDefault: row.readBool('userCompanyDefault'),
      ),
  ];

  /// [userId]'s activities from [from] up to [to], oldest first.
  Future<List<ActivityRow>> between(SqlExecutor executor, int userId, DateTime from, DateTime to) async =>
      (await ofUsers(executor, [userId], from, to))[userId] ?? const [];

  /// The activities of [userIds] from [from] up to [to], oldest first. The
  /// list holds only numbers from the server, each a bound placeholder.
  Future<Map<int, List<ActivityRow>>> ofUsers(
    SqlExecutor executor,
    List<int> userIds,
    DateTime from,
    DateTime to,
  ) async {
    if (userIds.isEmpty) return const {};
    final names = [for (var i = 0; i < userIds.length; i++) ':u$i'];
    final rows = await executor.query(
      'SELECT r.userID, r.timeRegID, t.timeRegTypeName, r.timeRegTimestamp, r.projectID, r.companyID, r.addressID, '
      'p.addressID AS projectAddressID FROM tblTimeReg r '
      'JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      'LEFT JOIN tblProject p ON p.projectID = r.projectID '
      'WHERE r.userID IN (${names.join(', ')}) AND r.timeRegActive = 1 AND r.timeRegMFD = 0 '
      'AND t.timeRegTypeName LIKE :prefix AND r.timeRegTimestamp >= :from AND r.timeRegTimestamp < :to '
      'ORDER BY r.timeRegTimestamp, r.timeRegID',
      {
        for (var i = 0; i < userIds.length; i++) 'u$i': userIds[i],
        'prefix': '$typePrefix%',
        'from': TimeRecordRepository.sqlDateTime(from),
        'to': TimeRecordRepository.sqlDateTime(to),
      },
    );
    final byUser = <int, List<ActivityRow>>{};
    for (final row in rows) {
      byUser.putIfAbsent(row.readInt('userID'), () => []).add((
        id: row.readInt('timeRegID'),
        typeName: row.readString('timeRegTypeName'),
        at: row.readUtcDateTime('timeRegTimestamp'),
        projectId: row.readOptionalInt('projectID'),
        companyId: row.readOptionalInt('companyID'),
        addressId: row.readOptionalInt('addressID'),
        projectAddressId: row.readOptionalInt('projectAddressID'),
      ));
    }
    return byUser;
  }

  /// The project addresses that are not [userId]'s: their phone has no reason
  /// to watch these (D40), and Android allows only so many.
  Future<Set<int>> otherProjectAddresses(SqlExecutor executor, int userId) async => {
    for (final row in await executor.query(
      'SELECT DISTINCT p.addressID FROM tblProject p WHERE p.addressID IS NOT NULL AND p.addressID NOT IN ('
      'SELECT own.addressID FROM tblProject own '
      'JOIN tblUserProject up ON up.projectID = own.projectID AND up.userProjectActive = 1 AND up.userProjectMFD = 0 '
      'JOIN tblProjectStatus s ON s.projectStatusID = own.projectStatusID AND s.projectStatusName <> :finished '
      'WHERE up.userID = :user AND own.projectActive = 1 AND own.projectMFD = 0 AND own.addressID IS NOT NULL)',
      {'user': userId, 'finished': _finishedStatus},
    ))
      row.readInt('addressID'),
  };

  /// Those of [userIds] with a group whose travel is work (D39). The list
  /// holds only numbers from the server, each a bound placeholder.
  Future<Set<int>> travelIsWork(SqlExecutor executor, List<int> userIds) async {
    if (userIds.isEmpty) return const {};
    final names = [for (var i = 0; i < userIds.length; i++) ':u$i'];
    final rows = await executor.query(
      'SELECT DISTINCT ug.userID FROM tblUserGroup ug '
      'JOIN tblGroup g ON g.groupID = ug.groupID AND g.groupTravelIsWork = 1 AND g.groupMFD = 0 '
      'WHERE ug.userID IN (${names.join(', ')}) AND ${MembershipFilters.activeGroup('ug')}',
      {for (var i = 0; i < userIds.length; i++) 'u$i': userIds[i]},
    );
    return {for (final row in rows) row.readInt('userID')};
  }

  /// `null` when there is no such group.
  Future<bool?> groupTravel(SqlExecutor executor, int groupId) async {
    final rows = await executor.query('SELECT groupTravelIsWork FROM tblGroup WHERE groupID = :id AND groupMFD = 0', {
      'id': groupId,
    });
    return rows.isEmpty ? null : rows.first.readBool('groupTravelIsWork');
  }

  Future<void> setGroupTravel(SqlExecutor tx, int groupId, {required bool travelIsWork}) async => tx.execute(
    'UPDATE tblGroup SET groupTravelIsWork = :value WHERE groupID = :id',
    {'id': groupId, 'value': travelIsWork ? 1 : 0},
  );

  /// Adds an activity row; `timeRegManualEntry = 0`, it is what happened.
  Future<int> insert(
    SqlExecutor tx, {
    required int userId,
    required int typeId,
    required DateTime at,
    int? projectId,
    int? companyId,
    int? addressId,
  }) async => (await tx.execute(
    'INSERT INTO tblTimeReg (userID, timeRegTypeID, timeRegTimestamp, timeRegManualEntry, projectID, companyID, '
    'addressID, timeRegActive, timeRegMFD) VALUES (:user, :type, :at, 0, :project, :company, :address, 1, 0)',
    {
      'user': userId,
      'type': typeId,
      'at': TimeRecordRepository.sqlDateTime(at),
      'project': projectId,
      'company': companyId,
      'address': addressId,
    },
  )).lastInsertId;
}
