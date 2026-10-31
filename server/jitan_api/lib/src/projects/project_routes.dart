import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'project_service.dart';

/// Projects. Consumer: the HR/Admin Projects page.
///
/// - `GET /project-options`: the form's types and statuses.
/// - `GET /projects`: every project where the viewer may see them, each
///   company checked on its own (ENGINEERING_RULES §28a.5).
/// - `POST /companies/{id}/projects` (`ProjectRequest`, 201).
/// - `GET` and `PUT /companies/{id}/projects/{projectId}`.
/// - `PUT /companies/{id}/projects/{projectId}/employees`
///   (`ProjectEmployeesRequest`): "Save assignments".
class ProjectRoutes {
  const ProjectRoutes(this._authorizer, this._projects);

  final Authorizer _authorizer;
  final ProjectService _projects;

  static const _company = '/companies/<companyId|[0-9]+>/projects';
  static const _project = '$_company/<projectId|[0-9]+>';

  Router get router => Router()
    ..get('/project-options', _options)
    ..get('/projects', _list)
    ..post(_company, _create)
    ..get(_project, _find)
    ..put(_project, _update)
    ..put('$_project/employees', _assign);

  Future<Response> _options(Request request) async {
    // 401 without an identity; the choices hold no company's data.
    request.identity;
    return jsonResponse((await _projects.options()).toJson());
  }

  Future<Response> _list(Request request) async {
    request.identity;
    final projects = await _projects.list(
      (id) => _authorizer.may(request, Permission.viewProjects, companyId: id),
    );
    return jsonResponse(ProjectListResponse(projects: projects).toJson());
  }

  Future<Response> _create(Request request, String companyId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageProjects, companyId: company);
    final created = await _projects.create(identity.userId, company, await _body(request));
    return jsonResponse(created.toJson(), statusCode: 201);
  }

  Future<Response> _find(Request request, String companyId, String projectId) async {
    final company = _companyId(companyId);
    await _authorizer.require(request, Permission.viewProjects, companyId: company);
    return jsonResponse((await _projects.find(company, _projectId(projectId))).toJson());
  }

  Future<Response> _update(Request request, String companyId, String projectId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageProjects, companyId: company);
    final updated = await _projects.update(identity.userId, company, _projectId(projectId), await _body(request));
    return jsonResponse(updated.toJson());
  }

  Future<Response> _assign(Request request, String companyId, String projectId) async {
    final company = _companyId(companyId);
    final identity = await _authorizer.require(request, Permission.manageProjects, companyId: company);
    final ProjectEmployeesRequest body;
    try {
      body = ProjectEmployeesRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    return jsonResponse((await _projects.assign(identity.userId, company, _projectId(projectId), body)).toJson());
  }

  static int _companyId(String raw) => pathId(raw, 'No such company.');

  static int _projectId(String raw) => pathId(raw, 'No such project.');

  Future<ProjectRequest> _body(Request request) async {
    try {
      return ProjectRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
