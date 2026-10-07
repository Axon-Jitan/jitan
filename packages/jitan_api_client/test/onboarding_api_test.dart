import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  final account = {
    'firstName': 'Disan',
    'lastName': 'Ssebowa',
    'code': 'SBW',
    'companies': ['Almeco'],
  };

  test('start posts the QR; complete posts the request and returns account + session', () async {
    final sent = <http.Request>[];
    final api = OnboardingApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((request) async {
          sent.add(request);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('start')
                  ? account
                  : {
                      'account': account,
                      'session': {'accessToken': 'T.O.K', 'expiresAt': '2026-11-06T12:00:00.000Z'},
                    },
            ),
            200,
          );
        }),
      ),
    );

    expect((await api.start('QR1')).code, 'SBW');
    final result = await api.complete(
      const OnboardingCompleteRequest(qrCode: 'QR1', password: 'correct horse', deviceId: 'device-1234567890ab'),
    );

    expect(result.account.companies, ['Almeco']);
    expect(result.session.accessToken, 'T.O.K');
    expect(sent.map((r) => r.url.path), ['/onboarding/start', '/onboarding/complete']);
    expect(jsonDecode(sent.last.body), containsPair('deviceId', 'device-1234567890ab'));
  });

  test('an already onboarded QR surfaces onboarding_already_completed', () async {
    final api = OnboardingApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'code': 'onboarding_already_completed', 'message': 'x'},
            }),
            409,
          ),
        ),
      ),
    );

    expect(
      api.start('QR1'),
      throwsA(isA<ApiClientException>().having((e) => e.error?.code, 'code', ApiErrorCode.onboardingAlreadyCompleted)),
    );
  });

  test('with a session every request carries the bearer token; signed out, none', () async {
    String? token;
    final headers = <String?>[];
    final me = MeApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        accessToken: () => token,
        httpClient: MockClient((request) async {
          headers.add(request.headers['authorization']);
          return http.Response(jsonEncode(account), 200);
        }),
      ),
    );

    await me.me();
    token = 'abc.def.ghi';
    await me.me();

    expect(headers, [null, 'Bearer abc.def.ghi']);
  });
}
