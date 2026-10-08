import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'employee_assignment_service.dart';

/// "Manage employee assignments" endpoints. Consumer: the HR/Admin
/// Employee details → Manage assignments modal (`apps/admin_web`).
///
/// - `GET  /companies/{companyId}/employees/{userId}/assignments/companies`
/// - `POST /companies/{companyId}/employees/{userId}/assignments/companies`
///   with an `AddAssignmentsRequest` (adds only)
/// - `GET/POST …/assignments/groups` (universal groups, adds only)
class EmployeeAssignmentRoutes {
  const EmployeeAssignmentRoutes(this._authorizer, this._assignments);

  final Authorizer _authorizer;
  final EmployeeAssignmentService _assignments;

  static const _path = '/companies/<companyId|[0-9]+>/employees/<userId|[0-9]+>/assignments';

  Router get router => Router()
    ..get('$_path/companies', _companies)
    ..post('$_path/companies', _addCompanies)
    ..get('$_path/groups', _groups)
    ..post('$_path/groups', _addGroups);

  Future<Response> _groups(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    return jsonResponse((await _assignments.groups(id, int.parse(userId))).toJson());
  }

  Future<Response> _addGroups(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    final result = await _assignments.addGroups(identity.userId, id, int.parse(userId), await _body(request));
    return jsonResponse(result.toJson());
  }

  Future<Response> _companies(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    return jsonResponse((await _assignments.companies(id, int.parse(userId))).toJson());
  }

  Future<Response> _addCompanies(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    final body = await _body(request);
    final result = await _assignments.addCompanies(
      identity.userId,
      id,
      int.parse(userId),
      body,
      mayManage: (target) => _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: target),
    );
    return jsonResponse(result.toJson());
  }

  static Future<AddAssignmentsRequest> _body(Request request) async {
    try {
      return AddAssignmentsRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
