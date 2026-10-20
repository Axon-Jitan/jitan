import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'group_management_service.dart';
import 'group_repository.dart';

/// Employee groups (e.g. Blue/White collar). Groups are universal across
/// companies, so nothing here is company-scoped.
///
/// - `GET /groups`: assignable (active) groups. Consumer: the "Employee
///   type" field of Add employee and Manage assignments.
/// - `GET /groups/overview`: every group, active or not, with its number of
///   employees. Consumer: the HR/Admin Employee groups screen (GRP-01, built
///   once its Figma frame arrives; staged, rule §32).
/// - `POST /groups` (`GroupNameRequest`, 201), `PUT /groups/{id}` (rename),
///   `POST /groups/{id}/deactivate`, `POST /groups/{id}/reactivate`.
class GroupRoutes {
  const GroupRoutes(this._authorizer, this._groups, this._management);

  final Authorizer _authorizer;
  final GroupRepository _groups;
  final GroupManagementService _management;

  static const _group = '/groups/<groupId|[0-9]+>';

  Router get router => Router()
    ..get('/groups', _list)
    ..get('/groups/overview', _overview)
    ..post('/groups', _create)
    ..put(_group, _rename)
    ..post('$_group/deactivate', _deactivate)
    ..post('$_group/reactivate', _reactivate);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewGroups);
    return jsonResponse(GroupListResponse(groups: await _groups.listActive()).toJson());
  }

  Future<Response> _overview(Request request) async {
    await _authorizer.require(request, Permission.viewGroups);
    return jsonResponse(GroupOverviewListResponse(groups: await _management.overview()).toJson());
  }

  Future<Response> _create(Request request) async {
    final identity = await _authorizer.require(request, Permission.manageGroups);
    final created = await _management.create(identity.userId, await _body(request));
    return jsonResponse(created.toJson(), statusCode: 201);
  }

  Future<Response> _rename(Request request, String groupId) async {
    final id = _id(groupId);
    final identity = await _authorizer.require(request, Permission.manageGroups);
    return jsonResponse((await _management.rename(identity.userId, id, await _body(request))).toJson());
  }

  Future<Response> _deactivate(Request request, String groupId) async {
    final id = _id(groupId);
    final identity = await _authorizer.require(request, Permission.manageGroups);
    return jsonResponse((await _management.deactivate(identity.userId, id)).toJson());
  }

  Future<Response> _reactivate(Request request, String groupId) async {
    final id = _id(groupId);
    final identity = await _authorizer.require(request, Permission.manageGroups);
    return jsonResponse((await _management.reactivate(identity.userId, id)).toJson());
  }

  static int _id(String raw) => pathId(raw, 'No such group.');

  static Future<GroupNameRequest> _body(Request request) async {
    try {
      return GroupNameRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
