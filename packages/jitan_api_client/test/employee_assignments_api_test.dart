import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

void main() {
  final options = {
    'options': [
      {'id': 1, 'name': 'Almeco', 'isActive': true, 'isAssigned': true},
      {'id': 2, 'name': 'PCA', 'isActive': true, 'isAssigned': false},
    ],
  };

  test('lists and adds company assignments of an employee in a company', () async {
    final sent = <http.Request>[];
    final api = EmployeeAssignmentsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode(options), 200);
      }),
    ));

    final listed = await api.options(1, 2, AssignmentKind.companies);
    await api.add(1, 2, AssignmentKind.companies, [2]);

    expect(listed.options.map((o) => o.name), ['Almeco', 'PCA']);
    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'GET /companies/1/employees/2/assignments/companies',
      'POST /companies/1/employees/2/assignments/companies',
    ]);
    expect(jsonDecode(sent.last.body), {'ids': [2]});
  });
}
