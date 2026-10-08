import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:test/test.dart';

void main() {
  final options = {
    'options': [
      {'id': 1, 'name': 'Almeco', 'isActive': true, 'isAssigned': true, 'isAssignable': false, 'isRemovable': false},
      {'id': 2, 'name': 'PCA', 'isActive': true, 'isAssigned': false, 'isAssignable': true, 'isRemovable': false},
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

  test('credential-group assignments use the credential-groups path', () async {
    final sent = <http.Request>[];
    final api = EmployeeAssignmentsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode(options), 200);
      }),
    ));

    await api.options(1, 2, AssignmentKind.credentialGroups);
    await api.add(1, 2, AssignmentKind.credentialGroups, [2]);

    expect(sent.map((r) => r.url.path).toSet(), {'/companies/1/employees/2/assignments/credential-groups'});
  });

  test('language is listed and replaced with PUT', () async {
    final sent = <http.Request>[];
    final api = EmployeeAssignmentsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode(options), 200);
      }),
    ));

    await api.options(1, 2, AssignmentKind.language);
    await api.setLanguage(1, 2, 3);

    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'GET /companies/1/employees/2/assignments/language',
      'PUT /companies/1/employees/2/assignments/language',
    ]);
    expect(jsonDecode(sent.last.body), {'languageId': 3});
  });

  test('removing a company or group uses DELETE on its id', () async {
    final sent = <http.Request>[];
    final api = EmployeeAssignmentsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode(options), 200);
      }),
    ));

    await api.remove(1, 2, AssignmentKind.companies, 3);
    await api.remove(1, 2, AssignmentKind.groups, 4);

    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'DELETE /companies/1/employees/2/assignments/companies/3',
      'DELETE /companies/1/employees/2/assignments/groups/4',
    ]);
  });

  test('group assignments use the groups path', () async {
    final sent = <http.Request>[];
    final api = EmployeeAssignmentsApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        sent.add(request);
        return http.Response(jsonEncode(options), 200);
      }),
    ));

    await api.options(1, 2, AssignmentKind.groups);
    await api.add(1, 2, AssignmentKind.groups, [2]);

    expect(sent.map((r) => '${r.method} ${r.url.path}'), [
      'GET /companies/1/employees/2/assignments/groups',
      'POST /companies/1/employees/2/assignments/groups',
    ]);
  });
}
