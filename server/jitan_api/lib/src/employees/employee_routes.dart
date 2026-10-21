import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/path_id.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'employee_service.dart';

/// HTTP endpoints for a company's employees. Consumer: the HR/Admin
/// Employees screen (`apps/admin_web`).
///
/// - `GET /companies/{companyId}/employees?search=<text>`
/// - `POST /companies/{companyId}/employees` with a `CreateEmployeeRequest`
/// - `GET /companies/{companyId}/employees/{userId}`
/// - `POST /companies/{companyId}/employees/{userId}/onboarding-qr`: a new
///   temporary onboarding QR (replaces the previous one)
/// - `POST /companies/{companyId}/employees/{userId}/reset-access`: "Reset
///   account access" (clears the password, ends every session)
/// - `POST /companies/{companyId}/employees/{userId}/recovery-qr`: a new
///   temporary recovery QR, after a reset
class EmployeeRoutes {
  const EmployeeRoutes(this._authorizer, this._employees);

  final Authorizer _authorizer;
  final EmployeeService _employees;

  static const _path = '/companies/<companyId|[0-9]+>/employees';
  static const _employeePath = '$_path/<userId|[0-9]+>';

  Router get router => Router()
    ..get(_path, _list)
    ..post(_path, _create)
    ..get(_employeePath, _details)
    ..post('$_employeePath/onboarding-qr', (Request r, String c, String u) => _temporaryQr(r, c, u, TemporaryQrPurpose.onboarding))
    ..post('$_employeePath/recovery-qr', (Request r, String c, String u) => _temporaryQr(r, c, u, TemporaryQrPurpose.recovery))
    ..post('$_employeePath/reset-access', _resetAccess);

  Future<Response> _resetAccess(Request request, String companyId, String userId) async {
    final id = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.resetEmployeeAccess, companyId: id);
    await _employees.resetAccess(identity.userId, id, _id(userId));
    return Response(204);
  }

  Future<Response> _temporaryQr(Request request, String companyId, String userId, TemporaryQrPurpose purpose) async {
    final id = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.issueTemporaryQr, companyId: id);
    final qr = await _employees.temporaryQr(identity.userId, id, _id(userId), purpose);
    // The value is a credential: keep it out of every cache.
    return jsonResponse(qr.toJson()).change(headers: const {'cache-control': 'no-store'});
  }

  Future<Response> _details(Request request, String companyId, String userId) async {
    final id = _companyId(companyId);
    await _authorizer.require(request, Permission.viewEmployees, companyId: id);
    final employee = _id(userId);
    return jsonResponse((await _employees.details(id, employee)).toJson());
  }

  Future<Response> _list(Request request, String companyId) async {
    final id = _companyId(companyId);
    await _authorizer.require(request, Permission.viewEmployees, companyId: id);
    final employees = await _employees.listForCompany(id, search: request.url.queryParameters['search']);
    return jsonResponse(EmployeeListResponse(companyId: id, employees: employees).toJson());
  }

  Future<Response> _create(Request request, String companyId) async {
    final id = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.createEmployee, companyId: id);
    final CreateEmployeeRequest body;
    try {
      body = CreateEmployeeRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    // Adding the employee to other companies needs the right there too.
    for (final other in body.companyIds) {
      if (other != id) await _authorizer.require(request, Permission.createEmployee, companyId: other);
    }
    final created = await _employees.create(identity.userId, id, body);
    return jsonResponse(created.toJson(), statusCode: 201);
  }

  static int _companyId(String raw) => pathId(raw, 'No such company.');

  static int _id(String raw) => pathId(raw, 'No such employee.');
}
