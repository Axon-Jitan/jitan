import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  final account = {'firstName': 'Disan', 'lastName': 'Ssebowa', 'code': 'SBW', 'companies': ['Almeco']};
  final session = {'accessToken': 'T.O.K', 'expiresAt': '2026-11-06T12:00:00.000Z'};

  ApiTransport transport(List<http.Request> sent, http.Response Function(http.Request) answer) => ApiTransport(
    baseUri: Uri.parse('http://api.test/'),
    accessToken: () => 'current-token',
    httpClient: MockClient((request) async {
      sent.add(request);
      return answer(request);
    }),
  );

  test('sign-in posts code, password and device id and returns the session', () async {
    final sent = <http.Request>[];
    final api = AuthApi(transport(sent, (_) => http.Response(jsonEncode({'account': account, 'session': session}), 200)));

    final result = await api.signIn(
      const SignInRequest(code: 'SBW', password: 'correct horse', deviceId: 'device-1234567890ab'),
    );

    expect(result.session.accessToken, 'T.O.K');
    expect(sent.single.url.path, '/auth/sign-in');
    expect(jsonDecode(sent.single.body), {'code': 'SBW', 'password': 'correct horse', 'deviceId': 'device-1234567890ab'});
  });

  test('a failed sign-in surfaces the generic invalid_credentials code', () async {
    final api = AuthApi(
      transport([], (_) => http.Response(jsonEncode({'error': {'code': 'invalid_credentials', 'message': 'x'}}), 401)),
    );

    expect(
      api.signIn(const SignInRequest(code: 'SBW', password: 'nope', deviceId: 'device-1234567890ab')),
      throwsA(isA<ApiClientException>().having((e) => e.error?.code, 'code', ApiErrorCode.invalidCredentials)),
    );
  });

  test('change password posts the new password with the session and returns a new session', () async {
    final sent = <http.Request>[];
    final api = MeApi(transport(sent, (_) => http.Response(jsonEncode({'account': account, 'session': session}), 200)));

    final result = await api.changePassword('a brand new password');

    expect(result.session.accessToken, 'T.O.K');
    expect(sent.single.url.path, '/me/password');
    expect(sent.single.headers['authorization'], 'Bearer current-token');
    expect(jsonDecode(sent.single.body), {'newPassword': 'a brand new password'});
  });

  test('reset account access accepts 204 No Content and surfaces 409 account_not_activated', () async {
    final sent = <http.Request>[];
    final ok = EmployeesApi(transport(sent, (_) => http.Response('', 204)));
    await ok.resetAccess(7, 1);
    expect(sent.single.url.path, '/companies/7/employees/1/reset-access');

    final notActivated = EmployeesApi(
      transport([], (_) => http.Response(jsonEncode({'error': {'code': 'account_not_activated', 'message': 'x'}}), 409)),
    );
    expect(
      notActivated.resetAccess(7, 1),
      throwsA(isA<ApiClientException>().having((e) => e.error?.code, 'code', ApiErrorCode.accountNotActivated)),
    );
  });
}
