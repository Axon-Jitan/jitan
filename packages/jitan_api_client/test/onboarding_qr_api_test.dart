import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('temporaryQr POSTs to the purpose path and decodes value, purpose and expiry', () async {
    final sent = <http.Request>[];
    final api = EmployeesApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        final purpose = request.url.path.endsWith('recovery-qr') ? 'recovery' : 'onboarding';
        return http.Response(jsonEncode({'qrCode': 'signed', 'purpose': purpose, 'expiresAt': '2026-10-08T12:10:00.000Z'}), 200);
      }),
    ));

    final onboarding = await api.temporaryQr(7, 1, TemporaryQrPurpose.onboarding);
    final recovery = await api.temporaryQr(7, 1, TemporaryQrPurpose.recovery);

    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'POST /companies/7/employees/1/onboarding-qr',
      'POST /companies/7/employees/1/recovery-qr',
    ]);
    expect((onboarding.qrCode, onboarding.purpose), ('signed', TemporaryQrPurpose.onboarding));
    expect(recovery.expiresAt, DateTime.utc(2026, 10, 8, 12, 10));
  });

  test('recovery start and complete use /recovery and return the session', () async {
    final sent = <http.Request>[];
    final api = RecoveryApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        final account = {'firstName': 'Kevin', 'lastName': null, 'code': 'KDV', 'companies': ['Almeco']};
        return http.Response(
          jsonEncode(request.url.path.endsWith('start')
              ? account
              : {'account': account, 'session': {'accessToken': 't', 'expiresAt': '2026-11-07T12:00:00.000Z'}}),
          200,
        );
      }),
    ));

    expect((await api.start('qr')).code, 'KDV');
    final session = await api.complete(const RecoveryCompleteRequest(qrCode: 'qr', password: 'new password', deviceId: 'd'));

    expect(session.session.accessToken, 't');
    expect(sent.map((r) => r.url.path), ['/recovery/start', '/recovery/complete']);
    expect(jsonDecode(sent.last.body), {'qrCode': 'qr', 'password': 'new password', 'deviceId': 'd'});
  });
}
