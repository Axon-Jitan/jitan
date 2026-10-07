import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  final account = {'firstName': 'Disan', 'lastName': 'Ssebowa', 'code': 'SBW', 'companies': ['Almeco']};

  test('start and complete POST the QR (and password) and decode the account', () async {
    final sent = <http.Request>[];
    final api = OnboardingApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode(account), 200);
      }),
    ));

    expect((await api.start('QR1')).code, 'SBW');
    expect((await api.complete('QR1', 'correct horse')).companies, ['Almeco']);
    expect(sent.map((r) => r.url.path), ['/onboarding/start', '/onboarding/complete']);
    expect(jsonDecode(sent.last.body), {'qrCode': 'QR1', 'password': 'correct horse'});
  });

  test('an already onboarded QR surfaces onboarding_already_completed', () async {
    final api = OnboardingApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({'error': {'code': 'onboarding_already_completed', 'message': 'x'}}),
            409,
          )),
    ));

    expect(
      api.start('QR1'),
      throwsA(isA<ApiClientException>()
          .having((e) => e.error?.code, 'code', ApiErrorCode.onboardingAlreadyCompleted)),
    );
  });
}
