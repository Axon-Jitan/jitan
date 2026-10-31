import 'package:jitan_models/jitan_models.dart';

import '../database/db_row.dart';
import '../database/sql_executor.dart';

/// `userProjectID` per employee of a project, for the audit.
typedef ProjectAssignmentChange = ({int userId, int userProjectId});

/// Data access for projects. PROPOSAL (docs/database/PROPOSED_TABLES.md): these
/// tables exist only in the local database until IT adds them. Writes run in
/// the caller's transaction, and nothing is deleted: leaving a project sets
/// `userProjectActive = 0, userProjectMFD = 1`, and coming back reactivates
/// the row.
class ProjectRepository {
  const ProjectRepository();

  static const _activeLink = 'up.userProjectActive = 1 AND up.userProjectMFD = 0';

  static const _select =
      'SELECT p.projectID, p.projectName, p.projectReference, p.companyID, c.companyName, '
      'p.projectTypeID, t.projectTypeName, p.projectStatusID, s.projectStatusName, '
      'p.projectStartDate, p.projectEndDate, p.projectDescription, p.addressID, a.addressLogicalName, '
      '(SELECT COUNT(*) FROM tblUserProject up WHERE up.projectID = p.projectID AND $_activeLink) AS teamSize '
      'FROM tblProject p '
      'JOIN tblCompany c ON c.companyID = p.companyID '
      'JOIN tblProjectType t ON t.projectTypeID = p.projectTypeID '
      'JOIN tblProjectStatus s ON s.projectStatusID = p.projectStatusID '
      'LEFT JOIN tblAddress a ON a.addressID = p.addressID '
      'WHERE p.projectMFD = 0 AND p.projectActive = 1';

  Future<List<ProjectChoice>> types(SqlExecutor executor) async => [
    for (final row in await executor.query(
      'SELECT projectTypeID, projectTypeName FROM tblProjectType '
      'WHERE projectTypeActive = 1 AND projectTypeMFD = 0 ORDER BY projectTypeID',
    ))
      ProjectChoice(id: row.readInt('projectTypeID'), name: row.readString('projectTypeName')),
  ];

  Future<List<ProjectChoice>> statuses(SqlExecutor executor) async => [
    for (final row in await executor.query(
      'SELECT projectStatusID, projectStatusName FROM tblProjectStatus '
      'WHERE projectStatusActive = 1 AND projectStatusMFD = 0 ORDER BY projectStatusID',
    ))
      ProjectChoice(id: row.readInt('projectStatusID'), name: row.readString('projectStatusName')),
  ];

  /// Every project of [companyIds], by name. The list holds only numbers from
  /// the server, and each goes in as a bound placeholder.
  Future<List<ProjectSummary>> list(SqlExecutor executor, List<int> companyIds) async {
    if (companyIds.isEmpty) return const [];
    final names = [for (var i = 0; i < companyIds.length; i++) ':c$i'];
    final rows = await executor.query(
      '$_select AND p.companyID IN (${names.join(', ')}) ORDER BY p.projectName, p.projectID',
      {for (var i = 0; i < companyIds.length; i++) 'c$i': companyIds[i]},
    );
    return rows.map(_toSummary).toList();
  }

  /// One project of [companyId]; `null` when it isn't one.
  Future<ProjectDetails?> find(SqlExecutor executor, int companyId, int projectId) async {
    final rows = await executor.query('$_select AND p.companyID = :company AND p.projectID = :id', {
      'company': companyId,
      'id': projectId,
    });
    if (rows.isEmpty) return null;
    final team = await executor.query(
      'SELECT u.userID, u.userName, u.userSurname, u.userCode FROM tblUserProject up '
      'JOIN tblUser u ON u.userID = up.userID '
      'WHERE up.projectID = :id AND $_activeLink AND u.userMFD = 0 ORDER BY u.userName, u.userSurname, u.userID',
      {'id': projectId},
    );
    final row = rows.first;
    DateTime date(DateTime value) => DateTime.utc(value.year, value.month, value.day);
    final end = row.readOptionalDateTime('projectEndDate');
    return ProjectDetails(
      summary: _toSummary(row),
      startDate: date(row.readOptionalDateTime('projectStartDate')!),
      endDate: end == null ? null : date(end),
      description: row.readOptionalString('projectDescription'),
      addressId: row.readOptionalInt('addressID'),
      addressName: row.readOptionalString('addressLogicalName'),
      employees: [
        for (final member in team)
          ProjectEmployee(
            id: member.readInt('userID'),
            code: member.readString('userCode'),
            firstName: member.readOptionalString('userName'),
            lastName: member.readOptionalString('userSurname'),
          ),
      ],
    );
  }

  /// Locks the project for the rest of the transaction; `false` when
  /// [companyId] has no such project.
  Future<bool> lock(SqlExecutor tx, int companyId, int projectId) async => (await tx.query(
    'SELECT projectID FROM tblProject '
    'WHERE projectID = :id AND companyID = :company AND projectMFD = 0 AND projectActive = 1 FOR UPDATE',
    {'id': projectId, 'company': companyId},
  )).isNotEmpty;

  Future<int> insert(SqlExecutor tx, int companyId, ProjectRequest project) async => (await tx.execute(
    'INSERT INTO tblProject (companyID, projectTypeID, projectStatusID, addressID, projectName, projectReference, '
    'projectStartDate, projectEndDate, projectDescription, projectActive, projectMFD) '
    'VALUES (:company, :type, :status, :address, :name, :reference, :start, :end, :description, 1, 0)',
    {'company': companyId, ..._parameters(project)},
  )).lastInsertId;

  Future<void> update(SqlExecutor tx, int projectId, ProjectRequest project) async => tx.execute(
    'UPDATE tblProject SET projectTypeID = :type, projectStatusID = :status, addressID = :address, '
    'projectName = :name, projectReference = :reference, projectStartDate = :start, projectEndDate = :end, '
    'projectDescription = :description WHERE projectID = :id',
    {'id': projectId, ..._parameters(project)},
  );

  /// userID → (`userProjectID`, counts now) of every row the project has.
  Future<Map<int, ({int id, bool current})>> links(SqlExecutor tx, int projectId) async => {
    for (final row in await tx.query(
      'SELECT userProjectID, userID, userProjectActive, userProjectMFD FROM tblUserProject '
      'WHERE projectID = :id FOR UPDATE',
      {'id': projectId},
    ))
      row.readInt('userID'): (
        id: row.readInt('userProjectID'),
        current: row.readBool('userProjectActive') && !row.readBool('userProjectMFD'),
      ),
  };

  Future<int> addLink(SqlExecutor tx, int userId, int projectId) async => (await tx.execute(
    'INSERT INTO tblUserProject (userID, projectID, userProjectDefault, userProjectActive, userProjectMFD) '
    'VALUES (:user, :project, 0, 1, 0)',
    {'user': userId, 'project': projectId},
  )).lastInsertId;

  Future<void> setLink(SqlExecutor tx, int userProjectId, {required bool current}) async => tx.execute(
    'UPDATE tblUserProject SET userProjectActive = :active, userProjectMFD = :removed WHERE userProjectID = :id',
    {'id': userProjectId, 'active': current ? 1 : 0, 'removed': current ? 0 : 1},
  );

  static Map<String, Object?> _parameters(ProjectRequest project) => {
    'type': project.typeId,
    'status': project.statusId,
    'address': project.addressId,
    'name': project.name,
    'reference': project.reference,
    'start': project.startDate,
    'end': project.endDate,
    'description': project.description,
  };

  static ProjectSummary _toSummary(DbRow row) => ProjectSummary(
    id: row.readInt('projectID'),
    name: row.readString('projectName'),
    reference: row.readOptionalString('projectReference'),
    companyId: row.readInt('companyID'),
    companyName: row.readString('companyName'),
    type: ProjectChoice(id: row.readInt('projectTypeID'), name: row.readString('projectTypeName')),
    status: ProjectChoice(id: row.readInt('projectStatusID'), name: row.readString('projectStatusName')),
    teamSize: row.readInt('teamSize'),
  );
}
