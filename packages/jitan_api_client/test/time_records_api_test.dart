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
}
