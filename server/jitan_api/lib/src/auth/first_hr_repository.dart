import '../database/database_exception.dart';
import '../database/sql_executor.dart';

/// A row IT keeps in one of its access tables, by name.
typedef AccessOption = ({int id, String name});

/// The SQL behind setting up the first HR person: IT's access groups
/// (`tblCredGroup`) and modules (`tblAppModules`), and the link between them
/// (`tblAppModulesCredGroup`). Names are read from IT's rows, never written
/// in the code.
class FirstHrRepository {
  const FirstHrRepository();

  static const _duplicateKey = 1062;

  /// The access groups a person can be given: active, not marked for deletion.
  Future<List<AccessOption>> accessGroups(SqlExecutor executor) async => [
    for (final row in await executor.query(
      'SELECT credGroupID, credGroupName FROM tblCredGroup WHERE credGroupActive = 1 AND credGroupMFD = 0 '
      'ORDER BY credGroupLevel DESC, credGroupName',
    ))
      (id: row.readInt('credGroupID'), name: row.readString('credGroupName')),
  ];

  /// The parts of Jitan a group can open: active modules.
  Future<List<AccessOption>> modules(SqlExecutor executor) async => [
    for (final row in await executor.query(
      'SELECT appModulesID, appModuleName FROM tblAppModules WHERE appModuleActive = 1 AND appModuleMFD = 0 '
      'ORDER BY appModuleName',
    ))
      (id: row.readInt('appModulesID'), name: row.readString('appModuleName')),
  ];

  /// Whether [credGroupId] already opens an active module: then its members
  /// may open HR (`CredentialAccessRepository.hasModuleAccess`).
  Future<bool> opensAModule(SqlExecutor executor, int credGroupId) async => (await executor.query(
    'SELECT 1 AS found FROM tblAppModulesCredGroup amcg '
    'JOIN tblAppModules am ON am.appModulesID = amcg.appModulesID AND am.appModuleActive = 1 AND am.appModuleMFD = 0 '
    'WHERE amcg.credGroupID = :group AND amcg.appModulesCredGroupActive = 1 AND amcg.appModulesCredGroupMFD = 0 LIMIT 1',
    {'group': credGroupId},
  )).isNotEmpty;

  /// Links [moduleId] to [credGroupId]: a new row, or its removed row
  /// switched on again. `null` when the link was already there.
  Future<int?> linkModule(SqlExecutor tx, int credGroupId, int moduleId) async {
    final rows = await tx.query(
      'SELECT appModulesCredGroupID AS id, (appModulesCredGroupActive = 1 AND appModulesCredGroupMFD = 0) AS current '
      'FROM tblAppModulesCredGroup WHERE credGroupID = :group AND appModulesID = :module',
      {'group': credGroupId, 'module': moduleId},
    );
    if (rows.isEmpty) {
      try {
        return (await tx.execute(
          'INSERT INTO tblAppModulesCredGroup (appModulesID, credGroupID, appModulesCredGroupActive, appModulesCredGroupMFD) '
          'VALUES (:module, :group, 1, 0)',
          {'group': credGroupId, 'module': moduleId},
        )).lastInsertId;
      } on DatabaseQueryException catch (e) {
        if (e.errorCode == _duplicateKey) return null;
        rethrow;
      }
    }
    final row = rows.first;
    if (row.readOptionalBool('current') ?? false) return null;
    final id = row.readInt('id');
    await tx.execute(
      'UPDATE tblAppModulesCredGroup SET appModulesCredGroupActive = 1, appModulesCredGroupMFD = 0 '
      'WHERE appModulesCredGroupID = :id',
      {'id': id},
    );
    return id;
  }

  /// The first and last name of [userId], to show whom the code belongs to.
  Future<String> nameOf(SqlExecutor executor, int userId) async {
    final row = (await executor.query('SELECT userName, userSurname FROM tblUser WHERE userID = :u', {'u': userId})).single;
    return '${row.readString('userName')} ${row.readString('userSurname')}'.trim();
  }

  /// Whether [userId] has a password (onboarding complete).
  Future<bool> hasPassword(SqlExecutor executor, int userId) async =>
      (await executor.query('SELECT 1 AS found FROM tblUser WHERE userID = :u AND userPassword IS NOT NULL', {'u': userId})).isNotEmpty;
}
