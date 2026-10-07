import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/json_response.dart';
import 'group_repository.dart';

/// `GET /groups`: assignable employee groups. Consumer: the "Employee type"
/// field of the HR/Admin Add employee form.
class GroupRoutes {
  const GroupRoutes(this._authorizer, this._groups);

  final Authorizer _authorizer;
  final GroupRepository _groups;

  Router get router => Router()..get('/groups', _list);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewGroups);
    return jsonResponse(GroupListResponse(groups: await _groups.listActive()).toJson());
  }
}
