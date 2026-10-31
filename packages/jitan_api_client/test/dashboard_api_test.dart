import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

void main() {
  DashboardApi api(MockClientHandler handler) =>
      DashboardApi(ApiTransport(baseUri: Uri.parse('http://api.test/'), httpClient: MockClient(handler)));

  const body = {
    'working': 1,
    'finished': 2,
    'notStarted': 3,
    'companies': <Object>[],
    'employees': 6,
    'employeesSetUp': 5,
    'locations': 2,
    'registeredMinutes': 60,
    'plannedMinutes': 120,
    'bucketSize': 'day',
    'buckets': <Object>[],
    'onTime': 4,
    'late': 3,
    'leftEarly': 2,
    'toReview': 1,
    'correctionsWaiting': 0,
  };

  test('asks for the period as dates', () async {
    late Uri asked;
    final dashboard = await api((r) async {
      asked = r.url;
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    }).dashboard(DateTime(2026, 10, 5), DateTime(2026, 10, 11));

    expect(asked.path, '/dashboard');
    expect(asked.queryParameters, {'from': '2026-10-05', 'to': '2026-10-11'});
    expect(dashboard.working, 1);
  });

  test('a broken answer is an invalid response', () async {
    final call = api(
      (r) async => http.Response('{"working":"x"}', 200, headers: {'content-type': 'application/json'}),
    ).dashboard(DateTime(2026, 10, 5), DateTime(2026, 10, 11));

    await expectLater(call, throwsA(isA<ApiClientException>()));
  });
}
