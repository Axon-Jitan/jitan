import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'schedule_editing_service.dart';
import 'schedule_service.dart';

/// Schedule endpoints (roadmap phase 2, staged backend milestone, rule §32).
/// Consumer: the HR/Admin Schedules list and the create/edit schedule form
/// (`apps/admin_web`), built once the updated Figma frames arrive. Schedules
/// are global (not company-scoped, CLARIFY-14).
///
/// - `GET /schedules`: every active group with its schedules
/// - `GET /schedules/options`: the form's days, intervals, tolerances and
///   break lengths
/// - `PUT /schedules/groups/{groupId}/work-hours` (`SetWorkHoursRequest`),
///   `DELETE …/work-hours`: set or remove a group's work hours
/// - `PUT /schedules/groups/{groupId}/breaks` (`SetBreaksRequest`),
///   `DELETE …/breaks`: set or remove a group's breaks
///
/// Writes answer with the group's schedule as it is afterwards.
class ScheduleRoutes {
  const ScheduleRoutes(this._authorizer, this._schedules, this._editing);

  final Authorizer _authorizer;
  final ScheduleService _schedules;
  final ScheduleEditingService _editing;

  static const _group = '/schedules/groups/<groupId|[0-9]+>';

  Router get router => Router()
    ..get('/schedules', _list)
    ..get('/schedules/options', _options)
    ..put('$_group/work-hours', _setWorkHours)
    ..delete('$_group/work-hours', _removeWorkHours)
    ..put('$_group/breaks', _setBreaks)
    ..delete('$_group/breaks', _removeBreaks);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewSchedules);
    return jsonResponse(GroupScheduleListResponse(groups: await _schedules.groupSchedules()).toJson());
  }

  Future<Response> _options(Request request) async {
    await _authorizer.require(request, Permission.viewSchedules);
    return jsonResponse((await _schedules.options()).toJson());
  }

  Future<Response> _setWorkHours(Request request, String groupId) async {
    final id = _groupId(groupId);
    final identity = await _authorizer.require(request, Permission.manageSchedules);
    final body = await _body(request, SetWorkHoursRequest.fromJson);
    return jsonResponse((await _editing.setWorkHours(identity.userId, id, body)).toJson());
  }

  Future<Response> _removeWorkHours(Request request, String groupId) async {
    final id = _groupId(groupId);
    final identity = await _authorizer.require(request, Permission.manageSchedules);
    return jsonResponse((await _editing.removeWorkHours(identity.userId, id)).toJson());
  }

  Future<Response> _setBreaks(Request request, String groupId) async {
    final id = _groupId(groupId);
    final identity = await _authorizer.require(request, Permission.manageSchedules);
    final body = await _body(request, SetBreaksRequest.fromJson);
    return jsonResponse((await _editing.setBreaks(identity.userId, id, body)).toJson());
  }

  Future<Response> _removeBreaks(Request request, String groupId) async {
    final id = _groupId(groupId);
    final identity = await _authorizer.require(request, Permission.manageSchedules);
    return jsonResponse((await _editing.removeBreaks(identity.userId, id)).toJson());
  }

  static int _groupId(String raw) => pathId(raw, 'No such group.');

  static Future<T> _body<T>(Request request, T Function(Map<String, Object?>) parse) async {
    try {
      return parse(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
