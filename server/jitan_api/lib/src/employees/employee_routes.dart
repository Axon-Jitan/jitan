import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'employee_service.dart';

/// HTTP endpoints for a company's employees. Consumer: the HR/Admin
/// Employees screen (`apps/admin_web`).
///
/// - `GET /companies/{companyId}/employees?search=<text>`
/// - `POST /companies/{companyId}/employees` with a `CreateEmployeeRequest`
/// - `GET /companies/{companyId}/employees/{userId}`
class EmployeeRoutes {
  const EmployeeRoutes(this._authorizer, this._employees);

  final Authorizer _authorizer;
  final EmployeeService _employees;

  static const _path = '/companies/<companyId|[0-9]+>/employees';
  static const _employeePath = '$_path/<userId|[0-9]+>';

  Router get router => Router()
    ..get(_path, _list)
    ..post(_path, _create)
    ..get(_employeePath, _details);

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
    final created = await _employees.create(identity.userId, id, body);
    return jsonResponse(created.toJson(), statusCode: 201);
  }

  static int _companyId(String raw) => int.tryParse(raw) ?? (throw const ApiException.notFound('No such company.'));

  static int _id(String raw) => int.tryParse(raw) ?? (throw const ApiException.notFound('No such employee.'));
}
