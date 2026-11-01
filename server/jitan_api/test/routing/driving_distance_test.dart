import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api/src/routing/driving_distance.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  const almeco = GeoPoint(latitude: 51.05, longitude: 3.72);
  const client = GeoPoint(latitude: 51.22, longitude: 4.40);

  test('asks for the normal route, and sends only the two places', () async {
    late Uri asked;
    final distance = MapboxDrivingDistance(
      token: 'pk.test',
      client: MockClient((request) async {
        asked = request.url;
        return http.Response(jsonEncode({'routes': [{'distance': 58123.4}]}), 200);
      }),
    );

    expect(await distance.metres(almeco, client), 58123);
    expect(asked.host, 'api.mapbox.com');
    expect(asked.path, '/directions/v5/mapbox/driving/3.72,51.05;4.4,51.22');
    expect(asked.queryParameters.keys, unorderedEquals(['access_token', 'overview', 'alternatives', 'steps']));
  });

  test('each direction is asked once', () async {
    var calls = 0;
    final distance = MapboxDrivingDistance(
      token: 'pk.test',
      client: MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'routes': [{'distance': 1000}]}), 200);
      }),
    );

    await distance.metres(almeco, client);
    await distance.metres(almeco, client);
    await distance.metres(client, almeco);

    expect(calls, 2);
  });

  test('a refusal, no route or a broken answer is no distance, and is asked again', () async {
    final answers = [
      http.Response('{"message":"Not Authorized"}', 401),
      http.Response(jsonEncode({'routes': <Object>[]}), 200),
      http.Response('not json', 200),
      http.Response(jsonEncode({'routes': [{'duration': 5}]}), 200),
      http.Response(jsonEncode({'routes': [{'distance': 700}]}), 200),
    ];
    final distance = MapboxDrivingDistance(token: 'pk.test', client: MockClient((_) async => answers.removeAt(0)));

    for (var i = 0; i < 4; i++) {
      expect(await distance.metres(almeco, client), isNull);
    }
    expect(await distance.metres(almeco, client), 700);
  });

  test('a failed request never logs the token', () async {
    final logged = <String>[];
    final subscription = Logger('routing').onRecord.listen((record) => logged.add(record.message));
    final distance = MapboxDrivingDistance(
      token: 'pk.secret',
      client: MockClient((request) async => throw http.ClientException('failed', request.url)),
    );

    expect(await distance.metres(almeco, client), isNull);

    await subscription.cancel();
    expect(logged, isNotEmpty);
    expect(logged.join(), isNot(contains('pk.secret')));
  });

  test('without a token, the distance is simply not known', () async {
    expect(await const NoDrivingDistance().metres(almeco, client), isNull);
  });
}
