import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

void main() {
  final page = {
    'registrations': [
      {
        'id': 10,
        'userId': 2,
        'timestamp': '2026-10-06T08:00:00.000',
        'typeId': 1,
        'typeName': 'x',
        'addressId': null,
        'addressName': null,
        'isManualEntry': false,
        'comment': null,
        'modifiedAt': null,
      },
    ],
    'nextCursor': 'next',
  };

  (TimeRegistrationsApi, List<Uri>) api() {
    final urls = <Uri>[];
    return (
      TimeRegistrationsApi(ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((request) async {
          urls.add(request.url);
          return http.Response(jsonEncode(page), 200);
        }),
      )),
      urls,
    );
  }

  test('reads an employee\'s registrations company-scoped, with wall-clock range and paging', () async {
    final (client, urls) = api();

    final result = await client.forEmployee(1, 2, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 8, 12, 30), limit: 50, cursor: 'c1');

    expect(urls.single.path, '/companies/1/employees/2/time-registrations');
    expect(urls.single.queryParameters, {'from': '2026-10-01T00:00:00', 'to': '2026-10-08T12:30:00', 'limit': '50', 'cursor': 'c1'});
    expect(result.registrations.single.timestamp, DateTime(2026, 10, 6, 8));
    expect(result.nextCursor, 'next');
  });

  test('reads the signed-in user\'s own registrations', () async {
    final (client, urls) = api();

    await client.mine(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 8));

    expect(urls.single.path, '/me/time-registrations');
    expect(urls.single.queryParameters.keys, ['from', 'to']);
  });

  test('a UTC time is refused, never converted (GAP-02)', () {
    final (client, urls) = api();

    expect(() => client.mine(from: DateTime.utc(2026, 10, 1), to: DateTime(2026, 10, 8)), throwsArgumentError);
    expect(urls, isEmpty);
  });
}
