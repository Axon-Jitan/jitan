import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/authorizer.dart';
import '../auth/permission.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
import '../http/json_response.dart';
import '../http/path_id.dart';
import 'location_service.dart';

/// Locations, the places where Jitan recognises employees. The ERD has no
/// company on an address yet (GAP-03), so nothing here is company-scoped.
/// Consumer: the HR/Admin Locations page.
///
/// - `GET /locations`: every location, active or not.
/// - `POST /locations` (`LocationRequest`, 201), `PUT /locations/{id}`.
/// - `POST /locations/{id}/deactivate`, `POST /locations/{id}/reactivate`.
class LocationRoutes {
  const LocationRoutes(this._authorizer, this._locations);

  final Authorizer _authorizer;
  final LocationService _locations;

  static const _location = '/locations/<locationId|[0-9]+>';

  Router get router => Router()
    ..get('/locations', _list)
    ..post('/locations', _create)
    ..put(_location, _update)
    ..post('$_location/deactivate', _deactivate)
    ..post('$_location/reactivate', _reactivate);

  Future<Response> _list(Request request) async {
    await _authorizer.require(request, Permission.viewLocations);
    return jsonResponse(LocationListResponse(locations: await _locations.all()).toJson());
  }

  Future<Response> _create(Request request) async {
    final identity = await _authorizer.require(request, Permission.manageLocations);
    final created = await _locations.create(identity.userId, await _body(request));
    return jsonResponse(created.toJson(), statusCode: 201);
  }

  Future<Response> _update(Request request, String locationId) async {
    final id = _id(locationId);
    final identity = await _authorizer.require(request, Permission.manageLocations);
    return jsonResponse((await _locations.update(identity.userId, id, await _body(request))).toJson());
  }

  Future<Response> _deactivate(Request request, String locationId) => _setActive(request, locationId, active: false);

  Future<Response> _reactivate(Request request, String locationId) => _setActive(request, locationId, active: true);

  Future<Response> _setActive(Request request, String locationId, {required bool active}) async {
    final id = _id(locationId);
    final identity = await _authorizer.require(request, Permission.manageLocations);
    return jsonResponse((await _locations.setActive(identity.userId, id, active: active)).toJson());
  }

  static int _id(String raw) => pathId(raw, 'No such location.');

  Future<LocationRequest> _body(Request request) async {
    try {
      return LocationRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
  }
}
