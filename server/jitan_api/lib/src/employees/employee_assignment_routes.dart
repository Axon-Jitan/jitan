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
/// - `DELETE …/assignments/companies/{companyId}`: remove a membership (soft
///   delete; needs the permission in that company too; not the path company)
/// - `GET/POST …/assignments/groups` (universal groups)
/// - `DELETE …/assignments/groups/{groupId}`: remove a group (soft delete)
/// - `GET/PUT …/assignments/language` (one preferred language, replaced)
/// - `GET/POST …/assignments/credential-groups` (access, adds only; POST
///   needs `manageEmployeeAccess` in every company of the employee)
class EmployeeAssignmentRoutes {
  const EmployeeAssignmentRoutes(this._authorizer, this._assignments);

  final Authorizer _authorizer;
  final EmployeeAssignmentService _assignments;

  static const _path = '/companies/<companyId|[0-9]+>/employees/<userId|[0-9]+>/assignments';

  Router get router => Router()
    ..get('$_path/companies', _companies)
    ..post('$_path/companies', _addCompanies)
    ..get('$_path/groups', _groups)
    ..post('$_path/groups', _addGroups)
    ..delete('$_path/companies/<targetId|[0-9]+>', _removeCompany)
    ..delete('$_path/groups/<targetId|[0-9]+>', _removeGroup)
    ..get('$_path/language', _languages)
    ..put('$_path/language', _setLanguage)
    ..get('$_path/credential-groups', _credentialGroups)
    ..post('$_path/credential-groups', _addCredentialGroups);

  Future<Response> _languages(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    return jsonResponse((await _assignments.languages(id, int.parse(userId))).toJson());
  }

  Future<Response> _setLanguage(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    final SetLanguageRequest body;
    try {
      body = SetLanguageRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    return jsonResponse((await _assignments.setLanguage(identity.userId, id, int.parse(userId), body)).toJson());
  }

  Future<Response> _credentialGroups(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAccess, companyId: id);
    return jsonResponse((await _assignments.credentialGroups(identity.userId, id, int.parse(userId))).toJson());
  }

  Future<Response> _addCredentialGroups(Request request, String companyId, String userId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAccess, companyId: id);
    final result = await _assignments.addCredentialGroups(
      identity.userId,
      id,
      int.parse(userId),
      await _body(request),
      mayManage: (member) => _authorizer.require(request, Permission.manageEmployeeAccess, companyId: member),
    );
    return jsonResponse(result.toJson());
  }

  Future<Response> _removeCompany(Request request, String companyId, String userId, String targetId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    final result = await _assignments.removeCompany(
      identity.userId,
      id,
      int.parse(userId),
      int.parse(targetId),
      mayManage: (target) => _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: target),
    );
    return jsonResponse(result.toJson());
  }

  Future<Response> _removeGroup(Request request, String companyId, String userId, String targetId) async {
    final id = int.parse(companyId);
    final identity = await _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: id);
    final result = await _assignments.removeGroup(identity.userId, id, int.parse(userId), int.parse(targetId));
    return jsonResponse(result.toJson());
  }

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
