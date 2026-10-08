import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/json_response.dart';
import 'time_registration_service.dart';

/// Read-only time-registration endpoints (staged backend milestone, rule
/// §32). Consumers: the HR/Admin Time Records screen and the employee app's
/// history, built once their designs and GAP-01/CLARIFY-02 allow.
///
/// - `GET /companies/{companyId}/employees/{userId}/time-registrations?from=&to=&limit=&cursor=`
///   (permission `viewTimeRegistrations` in that company)
/// - `GET /me/time-registrations?from=&to=&limit=&cursor=` (own registrations)
class TimeRegistrationRoutes {
  const TimeRegistrationRoutes(this._authorizer, this._registrations);

  final Authorizer _authorizer;
  final TimeRegistrationService _registrations;

  Router get router => Router()
    ..get('/companies/<companyId|[0-9]+>/employees/<userId|[0-9]+>/time-registrations', _forEmployee)
    ..get('/me/time-registrations', _mine);

  Future<Response> _forEmployee(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    await _authorizer.require(request, Permission.viewTimeRegistrations, companyId: id);
    final page = await _registrations.forEmployee(id, int.parse(userId), request.url.queryParameters);
    return jsonResponse(page.toJson());
  }

  Future<Response> _mine(Request request) async {
    final page = await _registrations.mine(request.identity.userId, request.url.queryParameters);
    return jsonResponse(page.toJson());
  }
}
