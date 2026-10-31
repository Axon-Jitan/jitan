import 'credential_access_repository.dart';
import 'permission.dart';
import 'permission_evaluator.dart';
import 'request_identity.dart';

/// Production permissions for V1 (product owner, 2026-10-31): IT gives HR
/// access in its own tables, and Jitan respects it. A person has access when
/// they hold an active credential group linked to an active module. A group
/// without modules, such as Employee, opens nothing.
///
/// HR and Admin have the same rights in V1, in any company (2026-10-13), so
/// every [Permission] asks the same question and `companyId` narrows nothing.
/// That is data, never a role name here (rule §18); finer rights per module
/// or `tblFunction` plug in here without any endpoint change.
class CredentialPermissionEvaluator implements PermissionEvaluator {
  const CredentialPermissionEvaluator(this._access);

  final CredentialAccessRepository _access;

  @override
  Future<bool> isAllowed(RequestIdentity identity, Permission permission, {int? companyId}) =>
      _access.hasModuleAccess(identity.userId);
}
