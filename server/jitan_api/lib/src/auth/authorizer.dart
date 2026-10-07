import 'package:shelf/shelf.dart';

import '../http/api_exception.dart';
import 'permission.dart';
import 'permission_evaluator.dart';
import 'request_identity.dart';

/// The one place endpoints check access.
class Authorizer {
  const Authorizer(this._evaluator);

  final PermissionEvaluator _evaluator;

  /// Returns the acting user if they hold [permission] (for [companyId],
  /// when the action targets one company).
  /// Throws 401 without an identity, 403 without the permission.
  Future<RequestIdentity> require(Request request, Permission permission, {int? companyId}) async {
    final identity = request.identity;
    if (!await _evaluator.isAllowed(identity, permission, companyId: companyId)) {
      throw const ApiException.forbidden('You do not have access to this resource.');
    }
    return identity;
  }
}
