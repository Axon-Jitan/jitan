import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('list sends the period, company and search, and decodes the days', () async {
    late http.Request sent;
    final api = TimeRecordsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'days': [
              {
                'employeeId': 1,
                'firstName': 'Disan',
                'lastName': 'Ssebowa',
                'employeeCode': 'SBW',
                'date': '2026-10-21',
                'status': 'missing_finish',
                'start': {
                  'actualId': 5,
                  'actual': '2026-10-21T06:04:00.000Z',
                  'rounded': '2026-10-21T06:15:00.000Z',
                  'method': 'qr',
                  'enteredByHand': false,
                  'actualLocal': '08:04',
                  'roundedLocal': '08:15',
                  'reason': null,
                },
                'finish': null,
              },
            ],
          }),
          200,
        );
      }),
    ));

    final [day] = await api.list(from: DateTime.utc(2026, 10, 19), to: DateTime.utc(2026, 10, 25), companyId: 7, search: ' dis ');

    expect(sent.url.queryParameters, {'from': '2026-10-19', 'to': '2026-10-25', 'company': '7', 'search': 'dis'});
    expect((day.status, day.start!.rounded, day.finish), (TimeRecordStatus.missingFinish, DateTime.utc(2026, 10, 21, 6, 15), null));
    expect(day.date, DateTime.utc(2026, 10, 21));
  });

  test('correct, non-work, approve and reject POST to the company of the employee and return the day', () async {
    final paths = <String>[];
    final bodies = <Object?>[];
    final api = TimeRecordsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        bodies.add(jsonDecode(request.body));
        return http.Response(jsonEncode({'days': []}), 200);
      }),
    ));
    final date = DateTime.utc(2026, 10, 22);

    await api.correct(7, 1, date, CorrectTimeRequest(boundary: RegistrationBoundary.finish, time: '16:22', reason: 'x'));
    await api.markNonWork(7, 1, date, 'Holiday');
    await api.approve(7, 1, 55);
    expect(await api.reject(7, 1, 55), isNull, reason: 'no day left');

    expect(paths, [
      '/companies/7/employees/1/time-records/2026-10-22/correct',
      '/companies/7/employees/1/time-records/2026-10-22/non-work',
      '/companies/7/employees/1/time-registrations/55/approve',
      '/companies/7/employees/1/time-registrations/55/reject',
    ]);
    expect(bodies[0], {'boundary': 'finish', 'time': '16:22', 'reason': 'x'});
    expect(bodies[1], {'reason': 'Holiday'});
  });
}
