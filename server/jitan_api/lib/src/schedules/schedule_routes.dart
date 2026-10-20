import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/json_response.dart';
import 'schedule_service.dart';

/// Read-only schedule endpoints (roadmap phase 2, staged backend milestone,
/// rule §32). Consumer: the HR/Admin Schedules list and the create/edit
/// schedule form (`apps/admin_web`), built once the updated Figma frames
/// arrive. Schedules are global (not company-scoped, CLARIFY-14).
///
/// - `GET /schedules`: every active group with its schedules
/// - `GET /schedules/options`: the form's days, intervals, tolerances and
///   break lengths
class ScheduleRoutes {
  const ScheduleRoutes(this._authorizer, this._schedules);

  final Authorizer _authorizer;
  final ScheduleService _schedules;

  Router get router => Router()
    ..get('/schedules', _list)
    ..get('/schedules/options', _options);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewSchedules);
    return jsonResponse(GroupScheduleListResponse(groups: await _schedules.groupSchedules()).toJson());
  }

  Future<Response> _options(Request request) async {
    await _authorizer.require(request, Permission.viewSchedules);
    return jsonResponse((await _schedules.options()).toJson());
  }
}
