import '../database/sql_executor.dart';

/// Reads what IT configured in the credential tables.
class CredentialAccessRepository {
  const CredentialAccessRepository(this._executor);

  final SqlExecutor _executor;

  /// Whether [userId] holds an active credential group linked to an active
  /// module. Every link in the chain counts only while Active = 1, MFD = 0.
  Future<bool> hasModuleAccess(int userId) async => (await _executor.query(
    'SELECT 1 AS found FROM tblUserCredGroup ucg '
    'JOIN tblCredGroup cg ON cg.credGroupID = ucg.credGroupID AND cg.credGroupActive = 1 AND cg.credGroupMFD = 0 '
    'JOIN tblAppModulesCredGroup amcg ON amcg.credGroupID = cg.credGroupID '
    'AND amcg.appModulesCredGroupActive = 1 AND amcg.appModulesCredGroupMFD = 0 '
    'JOIN tblAppModules am ON am.appModulesID = amcg.appModulesID AND am.appModuleActive = 1 AND am.appModuleMFD = 0 '
    'WHERE ucg.userID = :userId AND ucg.userCredGroupActive = 1 AND ucg.userCredGroupMFD = 0 LIMIT 1',
    {'userId': userId},
  )).isNotEmpty;
}
