import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  ReportsApi api(MockClientHandler handler) =>
      ReportsApi(ApiTransport(baseUri: Uri.parse('http://api.test/'), httpClient: MockClient(handler)));

  http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  test('the project report asks for the month and reads the projects', () async {
    late Uri asked;
    final report = ProjectReport(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 10, 31),
      projects: const [
        ProjectReportProject(
          project: ProjectSummary(id: 3, sapNumber: 'P-1042', name: 'Office refurbishment', isClientSite: true, isActive: true),
          workedMinutes: 480,
          travelMinutes: 50,
          trips: 1,
          distanceMetres: 36400,
          tripsWithoutDistance: 0,
          employees: [],
        ),
      ],
    );
    final answer = await api((r) async {
      asked = r.url;
      return ok(report.toJson());
    }).projects(DateTime(2026, 10), DateTime(2026, 10, 31));

    expect(asked.path, '/reports/projects');
    expect(asked.queryParameters, {'from': '2026-10-01', 'to': '2026-10-31'});
    expect(answer.projects.single.project.fullName, 'P-1042 Office refurbishment');
  });

  test('a broken project report is an invalid response', () async {
    expect(
      api((r) async => ok({'from': '2026-10-01'})).projects(DateTime(2026, 10), DateTime(2026, 10, 31)),
      throwsA(isA<ApiClientException>()),
    );
  });
}
