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
import 'group_member_service.dart';
import 'group_repository.dart';
import 'group_setup_service.dart';

/// Employee groups (e.g. Blue/White collar). Groups are universal across
/// companies, so nothing here is company-scoped.
///
/// - `GET /groups`: assignable (active) groups. Consumer: the "Employee
///   type" field of Add employee and Manage assignments.
/// - `GET /groups/overview`: every group, active or not, with its number of
///   employees. Consumer: the HR/Admin Employee groups screen (GRP-01, built
///   once its Figma frame arrives; staged, rule §32).
/// - `POST /groups` (`CreateGroupRequest`, 201): the group with its
///   employees and work hours, in one transaction (GroupSetupService).
/// - `GET /groups/candidates?search=`: employees for Create group's step 2,
///   before the group exists.
/// - `PUT /groups/{id}` (`GroupNameRequest`, rename),
///   `POST /groups/{id}/deactivate`, `POST /groups/{id}/reactivate`.
/// - `GET /groups/{id}/members`, `GET /groups/{id}/candidates?search=`,
///   `POST /groups/{id}/members` (`AddAssignmentsRequest`),
///   `DELETE /groups/{id}/members/{userId}`: the group page's employees,
///   from every company (GroupMemberService). Consumer: the HR/Admin
///   Employee groups screens.
class GroupRoutes {
  const GroupRoutes(this._authorizer, this._groups, this._management, this._members, this._setup);

  final Authorizer _authorizer;
  final GroupRepository _groups;
  final GroupManagementService _management;
  final GroupMemberService _members;
  final GroupSetupService _setup;

  static const _group = '/groups/<groupId|[0-9]+>';

  Router get router => Router()
    ..get('/groups', _list)
    ..get('/groups/overview', _overview)
    ..post('/groups', _create)
    ..get('/groups/candidates', _newGroupCandidates)
    ..put(_group, _rename)
    ..post('$_group/deactivate', _deactivate)
    ..post('$_group/reactivate', _reactivate)
    ..get('$_group/members', _listMembers)
    ..get('$_group/candidates', _candidates)
    ..post('$_group/members', _addMembers)
    ..delete('$_group/members/<userId|[0-9]+>', _removeMember);

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
    final CreateGroupRequest body;
    try {
      body = CreateGroupRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final created = await _setup.create(identity.userId, body, mayManage: _mayManage(request));
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

  /// The group page's members, from every company the user may see
  /// employees of.
  Future<Response> _listMembers(Request request, String groupId) async {
    final id = _id(groupId);
    await _authorizer.require(request, Permission.viewGroups);
    return _memberList(await _members.members(id, mayView: _mayView(request)));
  }

  /// Employees for a group still being created (`?search=`).
  Future<Response> _newGroupCandidates(Request request) async {
    await _authorizer.require(request, Permission.manageGroups);
    final search = request.url.queryParameters['search'];
    return _memberList(await _members.candidates(null, search: search, mayView: _mayView(request)));
  }

  /// Employees that can be added (`?search=` on name or code).
  Future<Response> _candidates(Request request, String groupId) async {
    final id = _id(groupId);
    await _authorizer.require(request, Permission.manageGroups);
    final search = request.url.queryParameters['search'];
    return _memberList(await _members.candidates(id, search: search, mayView: _mayView(request)));
  }

  Future<Response> _addMembers(Request request, String groupId) async {
    final id = _id(groupId);
    final identity = await _authorizer.require(request, Permission.manageGroups);
    final AddGroupMembersRequest body;
    try {
      body = AddGroupMembersRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final members = await _members.add(
      identity.userId,
      id,
      body.ids,
      followIds: body.followIds,
      mayManage: _mayManage(request),
      mayView: _mayView(request),
    );
    return _memberList(members);
  }

  Future<Response> _removeMember(Request request, String groupId, String userId) async {
    final id = _id(groupId);
    final user = pathId(userId, 'No such employee.');
    final identity = await _authorizer.require(request, Permission.manageGroups);
    final members = await _members.remove(
      identity.userId,
      id,
      user,
      mayManage: _mayManage(request),
      mayView: _mayView(request),
    );
    return _memberList(members);
  }

  Future<bool> Function(int companyId) _mayView(Request request) =>
      (companyId) => _authorizer.may(request, Permission.viewEmployees, companyId: companyId);

  /// A group applies in every company of the employee, so changing it needs
  /// the right in each of them.
  Future<void> Function(int companyId) _mayManage(Request request) =>
      (companyId) => _authorizer.require(request, Permission.manageEmployeeAssignments, companyId: companyId);

  static Response _memberList(List<GroupMember> members) =>
      jsonResponse(GroupMemberListResponse(members: members).toJson());

  static int _id(String raw) => pathId(raw, 'No such group.');

  static Future<GroupNameRequest> _body(Request request) async {
    try {
      return GroupNameRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
