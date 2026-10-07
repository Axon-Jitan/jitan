import 'package:logging/logging.dart';

import '../config/app_environment.dart';
import 'permission.dart';
import 'permission_evaluator.dart';
import 'request_identity.dart';

final _log = Logger('auth.dev_permissions');

/// DEVELOPMENT ONLY: allows every permission. Refuses construction in
/// production.
///
/// Stands in for the real evaluator while CLARIFY-10/11 are open. It encodes
/// no production roles or rules.
class DevelopmentPermissionEvaluator implements PermissionEvaluator {
  DevelopmentPermissionEvaluator(AppEnvironment environment) {
    if (!environment.allowsDevelopmentMechanisms) {
      throw StateError('Development permissions cannot be used in ${environment.name}.');
    }
    _log.warning('Development permissions ACTIVE: every permission is granted.');
  }

  @override
  Future<bool> isAllowed(RequestIdentity identity, Permission permission, {int? companyId}) async => true;
}
