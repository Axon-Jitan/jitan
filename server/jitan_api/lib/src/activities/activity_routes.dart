import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import 'activity_service.dart';

/// The signed-in employee's activity. Acts only on them, so no permission.
/// Consumer: the employee app's Home, Switch activity and My projects.
///
/// - `GET /me/activity`: what they're on, their projects and companies.
/// - `POST /me/activity` (`SwitchActivityRequest`): switch, the day goes on.
/// - `POST /me/activity/trip` (`TripRequest`, D40): on Automatic, the phone
///   left one location and stayed at another.
///
/// With [_activities] `null` (a database without the proposed tables), `GET`
/// says it is off and the rest is 404.
class ActivityRoutes {
  const ActivityRoutes(this._activities);

  final ActivityService? _activities;

  Router get router => Router()
    ..get('/me/activity', _mine)
    ..post('/me/activity', _switch)
    ..post('/me/activity/trip', _trip);

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
