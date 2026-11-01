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
import 'activity_service.dart';

/// The signed-in employee's activity. Acts only on them, so no permission.
/// Consumer: the employee app's Home, Switch activity and My projects.
///
/// - `GET /me/activity`: what they're on, their projects and companies.
/// - `POST /me/activity` (`SwitchActivityRequest`): switch, the day goes on.
/// - `POST /me/activity/trip` (`TripRequest`, D40): on Automatic, the phone
///   left one location and stayed at another.
/// - `GET` and `PUT /groups/{id}/travel` (`GroupTravel`, D39): whether a
///   group's travel counts as work. Consumer: the HR group page.
///
/// With [_activities] `null` (a database without the proposed tables), `GET`
/// says it is off and the rest is 404.
class ActivityRoutes {
  const ActivityRoutes(this._authorizer, this._activities);

  final Authorizer _authorizer;
  final ActivityService? _activities;

  static const _travel = '/groups/<groupId|[0-9]+>/travel';

  Router get router => Router()
    ..get('/me/activity', _mine)
    ..post('/me/activity', _switch)
    ..post('/me/activity/trip', _trip)
    ..get(_travel, _groupTravel)
    ..put(_travel, _setGroupTravel);

  Future<Response> _groupTravel(Request request, String groupId) async {
    final id = pathId(groupId, 'No such group.');
    await _authorizer.require(request, Permission.viewGroups);
    final activities = _activities;
    final travel = activities == null
        ? const GroupTravel(available: false, travelIsWork: false)
        : await activities.groupTravel(id);
    return jsonResponse(travel.toJson());
  }

  Future<Response> _setGroupTravel(Request request, String groupId) async {
    final id = pathId(groupId, 'No such group.');
    final identity = await _authorizer.require(request, Permission.manageGroups);
    final activities = _activities;
    if (activities == null) throw const ApiException.notFound('Not available.');
    final bool travelIsWork;
    try {
      travelIsWork = GroupTravel.fromJson(await readJsonObject(request)).travelIsWork;
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    return jsonResponse((await activities.setGroupTravel(identity.userId, id, travelIsWork: travelIsWork)).toJson());
  }

  Future<Response> _mine(Request request) async {
    final userId = request.identity.userId;
    final activities = _activities;
    return jsonResponse((activities == null ? MyActivity.disabled : await activities.mine(userId)).toJson());
  }

  Future<Response> _switch(Request request) async {
    final userId = request.identity.userId;
    final activities = _activities;
    if (activities == null) throw const ApiException.notFound('Activities are not available.');
    final SwitchActivityRequest body;
    try {
      body = SwitchActivityRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    return jsonResponse((await activities.switchTo(userId, body)).toJson());
  }

  Future<Response> _trip(Request request) async {
    final userId = request.identity.userId;
    final activities = _activities;
    if (activities == null) throw const ApiException.notFound('Activities are not available.');
    final TripRequest body;
    try {
      body = TripRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    return jsonResponse((await activities.registerTrip(userId, body)).toJson());
  }
}
