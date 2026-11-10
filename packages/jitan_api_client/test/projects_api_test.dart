import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const summary = ProjectSummary(
    id: 3,
    sapNumber: 'P-1057',
    name: 'Cooling towers',
    isClientSite: true,
    isActive: true,
    placeName: 'Engis',
  );
  const details = ProjectDetails(summary: summary);
  const request = ProjectRequest(sapNumber: 'P-1057', name: 'Cooling towers', workshopId: 5);

  test('list, read, add, change and switch off use /projects, with no company (D44)', () async {
    final requests = <http.Request>[];
    final api = ProjectsApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((r) async {
          requests.add(r);
          final body = r.url.path == '/projects' && r.method == 'GET'
              ? const ProjectListResponse(projects: [summary]).toJson()
              : details.toJson();
          return http.Response(jsonEncode(body), r.method == 'POST' ? 201 : 200, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    expect((await api.list()).single.fullName, 'P-1057 Cooling towers');
    expect((await api.find(3)).summary.placeName, 'Engis');
    await api.create(request);
    await api.update(3, request);
    await api.deactivate(3);
    await api.reactivate(3);

    expect(requests.map((r) => '${r.method} ${r.url.path}'), [
      'GET /projects',
      'GET /projects/3',
      'POST /projects',
      'PUT /projects/3',
      'POST /projects/3/deactivate',
      'POST /projects/3/reactivate',
    ]);
    expect(jsonDecode(requests[2].body), {'sapNumber': 'P-1057', 'name': 'Cooling towers', 'site': null, 'workshopId': 5});
  });

  test('a broken answer is an invalid response', () async {
    final api = ProjectsApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((r) async => http.Response('{}', 200, headers: {'content-type': 'application/json'})),
      ),
    );

    await expectLater(api.list(), throwsA(isA<ApiClientException>()));
  });
}
