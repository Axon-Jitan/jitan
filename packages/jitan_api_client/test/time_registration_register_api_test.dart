import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('register POSTs the moment in UTC with the reason and decodes the stored pair', () async {
    late http.Request sent;
    final api = TimeRegistrationsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'boundary': 'start',
            'actualId': 10,
            'actualAt': '2026-10-22T06:04:37.000Z',
            'roundedId': 11,
            'roundedAt': '2026-10-22T06:15:00.000Z',
          }),
          201,
        );
      }),
    ));

    final registered = await api.register(RegisterTimeRequest(
      boundary: RegistrationBoundary.start,
      method: TimeRegistrationMethod.manual,
      entry: RegistrationEntry.corrected,
      at: DateTime.parse('2026-10-22T08:04:37+02:00'),
      reason: 'Forgot my phone',
    ));

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/me/time-registrations');
    expect(jsonDecode(sent.body), {
      'boundary': 'start',
      'method': 'manual',
      'entry': 'corrected',
      'at': '2026-10-22T06:04:37.000Z',
      'reason': 'Forgot my phone',
    });
    expect((registered.actualId, registered.roundedAt), (10, DateTime.utc(2026, 10, 22, 6, 15)));
  });

  test('RegisterTimeRequest refuses a time without offset', () {
    expect(
      () => RegisterTimeRequest.fromJson({'boundary': 'start', 'method': 'manual', 'entry': 'now', 'at': '2026-10-22T06:04:00'}),
      throwsFormatException,
    );
  });

  test('today GETs the day of the signed-in employee and decodes it', () async {
    late http.Request sent;
    final api = TimeRegistrationsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'date': '2026-10-22',
            'firstDay': false,
            'scheduledStart': '08:00',
            'scheduledFinish': '16:30',
            'breakMinutes': 30,
            'day': {
              'employeeId': 1,
              'employeeCode': '',
              'date': '2026-10-22',
              'status': 'working',
              'start': {
                'actualId': 5,
                'actual': '2026-10-22T06:04:00.000Z',
                'rounded': '2026-10-22T06:04:00.000Z',
                'method': 'manual',
                'enteredByHand': false,
                'actualLocal': '08:04',
                'roundedLocal': '08:04',
              },
            },
            'registeredMinutes': null,
          }),
          200,
        );
      }),
    ));

    final today = await api.today();

    expect((sent.method, sent.url.path), ('GET', '/me/today'));
    expect((today.date, today.scheduledStart, today.breakMinutes, today.day!.status, today.day!.start!.actualLocal), (
      DateTime.utc(2026, 10, 22),
      '08:00',
      30,
      TimeRecordStatus.working,
      '08:04',
    ));
  });
}
