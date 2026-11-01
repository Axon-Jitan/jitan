import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

final _log = Logger('routing');

/// The driving distance of the normal route between two places (D23): the
/// outside service behind one interface, so tests need no network.
abstract interface class DrivingDistance {
  /// `null` when it can't be told: no guess ever takes its place.
  Future<int?> metres(GeoPoint from, GeoPoint to);
}

/// Without `JITAN_MAPBOX_TOKEN`: every distance is unknown.
class NoDrivingDistance implements DrivingDistance {
  const NoDrivingDistance();

  @override
  Future<int?> metres(GeoPoint from, GeoPoint to) async => null;
}

/// Mapbox Directions. Only the two coordinates are sent, never who is
/// travelling. Fixed places give a fixed distance, so each pair is asked once
/// and kept in memory; a failure is not kept, and is asked again next time.
class MapboxDrivingDistance implements DrivingDistance {
  MapboxDrivingDistance({required this._token, http.Client? client}) : _client = client ?? http.Client();

  final String _token;
  final http.Client _client;
  final _known = <String, int>{};

  static const _timeout = Duration(seconds: 10);

  @override
  Future<int?> metres(GeoPoint from, GeoPoint to) async {
    final route = '${_place(from)};${_place(to)}';
    final known = _known[route];
    if (known != null) return known;
    final uri = Uri.https('api.mapbox.com', '/directions/v5/mapbox/driving/$route', {
      'access_token': _token,
      'overview': 'false',
      'alternatives': 'false',
      'steps': 'false',
    });
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        _log.warning('Mapbox answered ${response.statusCode}.');
        return null;
      }
      final routes = (jsonDecode(response.body) as Map<String, Object?>)['routes']! as List<Object?>;
      if (routes.isEmpty) return null;
      final metres = ((routes.first! as Map<String, Object?>)['distance']! as num).round();
      return _known[route] = metres;
    } on Exception catch (e) {
      // Its type only: the message of a failed request holds the token.
      _log.warning('Mapbox could not be reached: ${e.runtimeType}.');
      return null;
    } on TypeError {
      _log.warning('Mapbox gave an answer without a distance.');
      return null;
    }
  }

  static String _place(GeoPoint point) => '${point.longitude},${point.latitude}';
}
