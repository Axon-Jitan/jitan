import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';
import '../http/json_request.dart';
import 'time_registration_service.dart';
import 'time_registration_write_service.dart';

/// Read-only time-registration endpoints (staged backend milestone, rule
/// §32). Consumers: the HR/Admin Time Records screen and the employee app's
/// history, built once their designs and GAP-01/CLARIFY-02 allow.
///
/// - `GET /companies/{companyId}/employees/{userId}/time-registrations?from=&to=&limit=&cursor=`
///   (permission `viewTimeRegistrations` in that company)
/// - `GET /me/time-registrations?from=&to=&limit=&cursor=` (own registrations)
/// - `POST /me/time-registrations` with a `RegisterTimeRequest`: the
///   employee's own start or finish (201; 200 for a retry of one already
///   stored). Acts only on the signed-in user, so it needs no permission.
///   Consumer: the employee app's Today screen (phase 3).
class TimeRegistrationRoutes {
  const TimeRegistrationRoutes(this._authorizer, this._registrations, this._writes);

  final Authorizer _authorizer;
  final TimeRegistrationService _registrations;
  final TimeRegistrationWriteService _writes;

  Router get router => Router()
    ..get('/companies/<companyId|[0-9]+>/employees/<userId|[0-9]+>/time-registrations', _forEmployee)
    ..get('/me/time-registrations', _mine)
    ..post('/me/time-registrations', _register);

  Future<Response> _register(Request request) async {
    final RegisterTimeRequest body;
    try {
      body = RegisterTimeRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final (:registered, :created) = await _writes.register(request.identity.userId, body);
    return jsonResponse(registered.toJson(), statusCode: created ? 201 : 200);
  }

  Future<Response> _forEmployee(Request request, String companyId, String userId) async {
    final id = pathId(companyId, 'No such company.');
    await _authorizer.require(request, Permission.viewTimeRegistrations, companyId: id);
    final page = await _registrations.forEmployee(id, pathId(userId, 'No such employee.'), request.url.queryParameters);
    return jsonResponse(page.toJson());
  }

  Future<Response> _mine(Request request) async {
    final page = await _registrations.mine(request.identity.userId, request.url.queryParameters);
    return jsonResponse(page.toJson());
  }
}
