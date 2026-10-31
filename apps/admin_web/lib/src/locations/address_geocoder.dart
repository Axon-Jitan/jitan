import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jitan_models/jitan_models.dart';

/// Finds an address on the map (Mapbox Geocoding), so HR starts close to the
/// entrance. Only the typed address goes to Mapbox. A failure is never an
/// error: the pin just stays, and HR places it by hand.
class AddressGeocoder {
  AddressGeocoder(this._token, {http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final String _token;
  final http.Client _http;

  /// The best match for [address]; `null` when there is none or Mapbox can't
  /// be reached.
  Future<GeoPoint?> find(String address) async {
    final uri = Uri.https('api.mapbox.com', '/search/geocode/v6/forward', {
      'q': address,
      'limit': '1',
      'access_token': _token,
    });
    try {
      final response = await _http.get(uri);
      if (response.statusCode != 200) return null;
      final features = (jsonDecode(response.body) as Map<String, Object?>)['features']! as List<Object?>;
      if (features.isEmpty) return null;
      final geometry = (features.first! as Map<String, Object?>)['geometry']! as Map<String, Object?>;
      final coordinates = geometry['coordinates']! as List<Object?>;
      return GeoPoint(latitude: (coordinates[1]! as num).toDouble(), longitude: (coordinates[0]! as num).toDouble());
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
  }
}
