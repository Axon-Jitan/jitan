import 'permission.dart';
import 'request_identity.dart';

/// Decides whether a user may perform an action.
///
/// [companyId] is set when the action targets one company's data (e.g. its
/// employees). Company scoping is enforced here, server-side: the production
/// evaluator decides what the user may do there.
///
/// Implementations:
/// - [DevelopmentPermissionEvaluator]: development/test only, allows all.
/// - [CredentialPermissionEvaluator]: production, on the ERD's credential
///   tables.
abstract interface class PermissionEvaluator {
  Future<bool> isAllowed(RequestIdentity identity, Permission permission, {int? companyId});
}
