import 'permission.dart';
import 'permission_evaluator.dart';
import 'request_identity.dart';

/// Production evaluator until the ERD permission model is clarified
/// (CLARIFY-10, CLARIFY-11): denies everything rather than guessing.
class UnconfiguredPermissionEvaluator implements PermissionEvaluator {
  const UnconfiguredPermissionEvaluator();

  @override
  Future<bool> isAllowed(RequestIdentity identity, Permission permission, {int? companyId}) async =>
      false;
}
