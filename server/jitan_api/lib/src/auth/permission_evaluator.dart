import 'permission.dart';
import 'request_identity.dart';

/// Decides whether a user may perform an action.
///
/// Implementations:
/// - [DevelopmentPermissionEvaluator]: development/test only, allows all.
/// - [UnconfiguredPermissionEvaluator]: production until CLARIFY-10/11 are
///   answered, denies all.
/// - The production evaluator built on the ERD permission tables replaces the
///   latter without any endpoint change.
abstract interface class PermissionEvaluator {
  Future<bool> isAllowed(RequestIdentity identity, Permission permission);
}
