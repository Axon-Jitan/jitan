import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const summary = ProjectSummary(
    id: 3,
    name: 'Cooling towers',
    reference: 'PRJ-1',
    companyId: 7,
    companyName: 'Almeco',
    type: ProjectChoice(id: 1, name: 'Client'),
    status: ProjectChoice(id: 2, name: 'Active'),
    teamSize: 1,
  );
  final details = ProjectDetails(
    summary: summary,
    startDate: DateTime.utc(2026, 10, 19),
    addressId: 5,
    addressName: 'Prayon site',
    employees: const [ProjectEmployee(id: 11, code: 'SBW', firstName: 'Disan', lastName: 'Ssebowa')],
  );
  const request = ProjectRequest(name: 'Cooling towers', typeId: 1, statusId: 2, startDate: '2026-10-19', addressId: 5);

  test('list, read, add, change and assign use the company in the path', () async {
    final requests = <http.Request>[];
    final api = ProjectsApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((r) async {
          requests.add(r);
          final body = r.url.path == '/projects' ? ProjectListResponse(projects: const [summary]).toJson() : details.toJson();
          return http.Response(jsonEncode(body), r.method == 'POST' ? 201 : 200, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    expect((await api.list()).single.name, 'Cooling towers');
    expect((await api.find(7, 3)).employees.single.code, 'SBW');
    expect((await api.create(7, request)).addressName, 'Prayon site');
    await api.update(7, 3, request);
    await api.assign(7, 3, [11, 12]);

    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'GET /projects',
      'GET /companies/7/projects/3',
      'POST /companies/7/projects',
      'PUT /companies/7/projects/3',
      'PUT /companies/7/projects/3/employees',
    ]);
    expect(jsonDecode(requests.last.body), {'employeeIds': [11, 12]});
  });

  test('a broken answer is an invalid response', () async {
    final api = ProjectsApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((r) async => http.Response('{}', 200, headers: {'content-type': 'application/json'})),
      ),
    );

    await expectLater(api.options(), throwsA(isA<ApiClientException>()));
  });
}
