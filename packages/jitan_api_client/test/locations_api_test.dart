import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const office = Location(
    id: 5,
    name: 'Almeco office',
    street: 'Rue du Progrès',
    number: '12',
    point: GeoPoint(latitude: 50.7436, longitude: 3.2167),
    radiusMeters: 50,
    isActive: true,
  );
  const request = LocationRequest(
    name: 'Almeco office',
    street: 'Rue du Progrès',
    point: GeoPoint(latitude: 50.7436, longitude: 3.2167),
    radiusMeters: 50,
  );

  test('manages locations: list, add, change, deactivate, reactivate', () async {
    final requests = <http.Request>[];
    final api = LocationsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((r) async {
        requests.add(r);
        final list = r.method == 'GET';
        final body = list ? const LocationListResponse(locations: [office]).toJson() : office.toJson();
        return http.Response.bytes(utf8.encode(jsonEncode(body)), r.method == 'POST' && r.url.path == '/locations' ? 201 : 200);
      }),
    ));

    final listed = (await api.list()).single;
    expect((listed.street, listed.point?.longitude, listed.city), ('Rue du Progrès', 3.2167, null));
    expect((await api.create(request)).radiusMeters, 50);
    await api.update(5, request);
    await api.deactivate(5);
    await api.reactivate(5);

    expect([for (final r in requests) '${r.method} ${r.url.path}'], [
      'GET /locations',
      'POST /locations',
      'PUT /locations/5',
      'POST /locations/5/deactivate',
      'POST /locations/5/reactivate',
    ]);
    expect(jsonDecode(requests[1].body), containsPair('radiusMeters', 50));
  });

  test('a location without readable coordinates still loads, with no pin', () {
    final json = {...office.toJson(), 'point': null};

    expect(Location.fromJson(json).point, isNull);
  });

  test('a whole-number coordinate is read as a number', () {
    expect(GeoPoint.fromJson({'latitude': 50, 'longitude': 3}).latitude, 50.0);
  });
}
