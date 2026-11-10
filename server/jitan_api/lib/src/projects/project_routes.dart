import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'project_service.dart';

/// Projects (D43, D44). Consumer: the HR/Admin Projects page (Figma
/// `1512:2` …). A project belongs to no company in Jitan (SAP knows it), so
/// these paths have none: the permission is checked without one.
///
/// - `GET /projects` and `POST /projects` (`ProjectRequest`, 201).
/// - `GET` and `PUT /projects/{id}`.
/// - `POST /projects/{id}/deactivate` and `/reactivate`.
class ProjectRoutes {
  const ProjectRoutes(this._authorizer, this._projects);

  final Authorizer _authorizer;
  final ProjectService _projects;

  static const _project = '/projects/<projectId|[0-9]+>';

  Router get router => Router()
    ..get('/projects', _list)
    ..post('/projects', _create)
    ..get(_project, _find)
    ..put(_project, _update)
    ..post('$_project/deactivate', _deactivate)
    ..post('$_project/reactivate', _reactivate);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewProjects);
    return jsonResponse(ProjectListResponse(projects: await _projects.list()).toJson());
  }

  Future<Response> _find(Request request, String projectId) async {
    await _authorizer.require(request, Permission.viewProjects);
    return jsonResponse((await _projects.find(_id(projectId))).toJson());
  }

  Future<Response> _create(Request request) async {
    final identity = await _authorizer.require(request, Permission.manageProjects);
    return jsonResponse((await _projects.create(identity.userId, await _body(request))).toJson(), statusCode: 201);
  }

  Future<Response> _update(Request request, String projectId) async {
    final identity = await _authorizer.require(request, Permission.manageProjects);
    return jsonResponse((await _projects.update(identity.userId, _id(projectId), await _body(request))).toJson());
  }

  Future<Response> _deactivate(Request request, String projectId) => _setActive(request, projectId, active: false);

  Future<Response> _reactivate(Request request, String projectId) => _setActive(request, projectId, active: true);

  Future<Response> _setActive(Request request, String projectId, {required bool active}) async {
    final identity = await _authorizer.require(request, Permission.manageProjects);
    return jsonResponse((await _projects.setActive(identity.userId, _id(projectId), active: active)).toJson());
  }

  static int _id(String raw) => pathId(raw, 'No such project.');

  Future<ProjectRequest> _body(Request request) async {
    try {
      return ProjectRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
