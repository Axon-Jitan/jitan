import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_response.dart';
import 'employee_service.dart';

/// HTTP endpoints for a company's employees.
///
/// `GET /companies/{companyId}/employees?search=<text>`: consumer is the
/// HR/Admin Employees screen (`apps/admin_web`).
class EmployeeRoutes {
  const EmployeeRoutes(this._authorizer, this._employees);

  final Authorizer _authorizer;
  final EmployeeService _employees;

  Router get router => Router()..get('/companies/<companyId|[0-9]+>/employees', _list);

  Future<Response> _list(Request request, String companyId) async {
    final id = int.tryParse(companyId) ?? (throw const ApiException.notFound('No such company.'));
    await _authorizer.require(request, Permission.viewEmployees, companyId: id);
    final employees = await _employees.listForCompany(id, search: request.url.queryParameters['search']);
    return jsonResponse(EmployeeListResponse(companyId: id, employees: employees).toJson());
  }
}
