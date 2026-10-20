import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const drivers = GroupOverview(id: 5, name: 'Drivers', isActive: true, employeeCount: 3);

  test('manages groups: overview, add, rename, deactivate, reactivate', () async {
    final requests = <http.Request>[];
    final api = GroupManagementApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = request.url.path == '/groups/overview'
            ? const GroupOverviewListResponse(groups: [drivers]).toJson()
            : drivers.toJson();
        return http.Response(jsonEncode(body), request.method == 'POST' && request.url.path == '/groups' ? 201 : 200);
      }),
    ));

    expect((await api.overview()).single.employeeCount, 3);
    expect((await api.create('Drivers')).name, 'Drivers');
    await api.rename(5, 'Van drivers');
    await api.deactivate(5);
    await api.reactivate(5);

    expect([for (final r in requests) '${r.method} ${r.url.path}'], [
      'GET /groups/overview',
      'POST /groups',
      'PUT /groups/5',
      'POST /groups/5/deactivate',
      'POST /groups/5/reactivate',
    ]);
    expect(jsonDecode(requests[2].body), {'name': 'Van drivers'});
  });
}
