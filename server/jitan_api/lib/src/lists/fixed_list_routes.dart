import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_response.dart';
import 'fixed_list_service.dart';

/// The fixed lists. Consumer: the HR/Admin Lists page (Figma `1510:2`).
///
/// - `GET /lists`: every list with what it has and misses.
/// - `GET /lists/{kind}`: one list's entries.
/// - `POST /lists/{kind}/add-missing`: adds what that list misses.
/// - `POST /lists/add-missing`: adds what every list misses.
class FixedListRoutes {
  const FixedListRoutes(this._authorizer, this._lists);

  final Authorizer _authorizer;
  final FixedListService _lists;

  Router get router => Router()
    ..get('/lists', _overview)
    ..post('/lists/add-missing', _addAll)
    ..get('/lists/<kind>', _detail)
    ..post('/lists/<kind>/add-missing', _add);

  Future<Response> _overview(Request request) async {
    await _authorizer.require(request, Permission.viewLists);
    return jsonResponse((await _lists.overview()).toJson());
  }

  Future<Response> _detail(Request request, String kind) async {
    await _authorizer.require(request, Permission.viewLists);
    return jsonResponse((await _lists.detail(_kind(kind))).toJson());
  }

  Future<Response> _add(Request request, String kind) async {
    final identity = await _authorizer.require(request, Permission.manageLists);
    return jsonResponse((await _lists.addMissing(identity.userId, _kind(kind))).toJson());
  }

  Future<Response> _addAll(Request request) async {
    final identity = await _authorizer.require(request, Permission.manageLists);
    return jsonResponse((await _lists.addAllMissing(identity.userId)).toJson());
  }

  static FixedListKind _kind(String raw) =>
      FixedListKind.fromWire(raw) ?? (throw const ApiException.notFound('No such list.'));
}
