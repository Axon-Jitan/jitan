import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

void main() {
  test('onboardingQr POSTs to the employee and returns the value', () async {
    late http.Request sent;
    final api = EmployeesApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'qrCode': 'abc123'}), 200);
      }),
    ));

    expect(await api.onboardingQr(7, 1), 'abc123');
    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'http://api.test/companies/7/employees/1/onboarding-qr');
  });
}
