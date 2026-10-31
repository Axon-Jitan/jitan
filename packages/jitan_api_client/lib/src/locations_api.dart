import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin managing locations: every location, add, change, deactivate and
/// reactivate.
class LocationsApi {
  const LocationsApi(this._transport);

  final ApiTransport _transport;

  /// Every location, active or not.
  Future<List<Location>> list() async {
    final json = await _transport.getJson('locations');
    try {
      return LocationListResponse.fromJson(json).locations;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Locations: ${e.message}');
    }
  }

  Future<Location> create(LocationRequest request) async =>
      _location(await _transport.postJson('locations', request.toJson()));

  Future<Location> update(int locationId, LocationRequest request) async =>
      _location(await _transport.putJson('locations/$locationId', request.toJson()));

  Future<Location> deactivate(int locationId) async =>
      _location(await _transport.postJson('locations/$locationId/deactivate', const {}));

  Future<Location> reactivate(int locationId) async =>
      _location(await _transport.postJson('locations/$locationId/reactivate', const {}));

  static Location _location(Map<String, Object?> json) {
    try {
      return Location.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Location: ${e.message}');
    }
  }
}
