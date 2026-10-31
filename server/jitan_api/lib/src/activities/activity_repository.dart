import 'package:jitan_models/jitan_models.dart';

import '../database/sql_executor.dart';
import '../employees/membership_filters.dart';
import '../time_records/time_record_repository.dart';

/// One activity row of `tblTimeReg`.
typedef ActivityRow = ({int id, String typeName, DateTime at, int? projectId, int? companyId});

/// A project with what the employee's history says about it.
typedef AssignedProject = ({MyProject project, DateTime? lastUsed});

/// Data access for activities (D19, D22, D37). PROPOSAL
/// (docs/database/PROPOSED_TABLES.md): uses tables and columns that exist only
/// in the local database, so nothing here runs where they are missing. The
/// Start and Finish rows are not touched: an activity is a row of its own.
class ActivityRepository {
  const ActivityRepository();

  /// `tblTimeRegType` names of activities start with this.
  static const typePrefix = 'Activity – ';

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
      'SELECT p.projectID, p.projectName, p.companyID, c.companyName, t.projectTypeName, s.projectStatusName, '
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
  Future<List<ActivityRow>> between(SqlExecutor executor, int userId, DateTime from, DateTime to) async => [
    for (final row in await executor.query(
      'SELECT r.timeRegID, t.timeRegTypeName, r.timeRegTimestamp, r.projectID, r.companyID FROM tblTimeReg r '
      'JOIN tblTimeRegType t ON t.timeRegTypeID = r.timeRegTypeID '
      'WHERE r.userID = :user AND r.timeRegActive = 1 AND r.timeRegMFD = 0 '
      'AND t.timeRegTypeName LIKE :prefix AND r.timeRegTimestamp >= :from AND r.timeRegTimestamp < :to '
      'ORDER BY r.timeRegTimestamp, r.timeRegID',
      {
        'user': userId,
        'prefix': '$typePrefix%',
        'from': TimeRecordRepository.sqlDateTime(from),
        'to': TimeRecordRepository.sqlDateTime(to),
      },
    ))
      (
        id: row.readInt('timeRegID'),
        typeName: row.readString('timeRegTypeName'),
        at: row.readUtcDateTime('timeRegTimestamp'),
        projectId: row.readOptionalInt('projectID'),
        companyId: row.readOptionalInt('companyID'),
      ),
  ];

  /// Adds an activity row; `timeRegManualEntry = 0`, it is what happened.
  Future<int> insert(
    SqlExecutor tx, {
    required int userId,
    required int typeId,
    required DateTime at,
    int? projectId,
    int? companyId,
  }) async => (await tx.execute(
    'INSERT INTO tblTimeReg (userID, timeRegTypeID, timeRegTimestamp, timeRegManualEntry, projectID, companyID, '
    'timeRegActive, timeRegMFD) VALUES (:user, :type, :at, 0, :project, :company, 1, 0)',
    {
      'user': userId,
      'type': typeId,
      'at': TimeRecordRepository.sqlDateTime(at),
      'project': projectId,
      'company': companyId,
    },
  )).lastInsertId;
}
