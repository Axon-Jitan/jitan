import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

void main() {
  test('requests the company-scoped path with a trimmed search', () async {
    final urls = <Uri>[];
    final api = EmployeesApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        urls.add(request.url);
        return http.Response(
          jsonEncode({
            'companyId': 7,
            'employees': [
              {'id': 1, 'firstName': 'Disan', 'lastName': 'Ssebowa', 'code': 'SBW', 'groups': ['White collar'], 'isActive': true},
            ],
          }),
          200,
        );
      }),
    ));

    final employees = await api.listForCompany(7, search: ' sbw ');
    await api.listForCompany(7);

    expect(urls.map((u) => u.toString()), [
      'http://api.test/companies/7/employees?search=sbw',
      'http://api.test/companies/7/employees',
    ]);
    expect(employees.single.groups, ['White collar']);
  });

  test('a contract mismatch is an invalid response', () async {
    final api = EmployeesApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((_) async => http.Response(jsonEncode({'companyId': 7, 'employees': [{'id': 'x'}]}), 200)),
    ));

    expect(
      api.listForCompany(7),
      throwsA(isA<ApiClientException>().having((e) => e.kind, 'kind', ApiFailureKind.invalidResponse)),
    );
  });
}
