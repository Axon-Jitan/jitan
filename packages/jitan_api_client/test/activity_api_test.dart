import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const project = MyProject(id: 3, name: 'Cooling towers', companyId: 7, companyName: 'Almeco', isClient: true, isCurrent: true);
  final mine = MyActivity(
    enabled: true,
    current: CurrentActivity(kind: ActivityKind.clientOnSite, since: DateTime.utc(2026, 10, 22, 6), project: project),
    projects: const [project],
    companies: const [MyCompany(id: 7, name: 'Almeco', isDefault: true)],
  );

  test('reads the activity and switches it', () async {
    final requests = <http.Request>[];
    final api = ActivityApi(
      ApiTransport(
        baseUri: Uri.parse('http://api.test/'),
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode(mine.toJson()), 200, headers: {'content-type': 'application/json'});
        }),
      ),
    );

    expect((await api.mine()).current?.project?.name, 'Cooling towers');
    await api.switchTo(SwitchActivityRequest(kind: ActivityKind.transport, at: DateTime.utc(2026, 10, 22, 8), projectId: 3));

    expect(requests.map((r) => '${r.method} ${r.url.path}'), ['GET /me/activity', 'POST /me/activity']);
    expect(jsonDecode(requests.last.body), {'kind': 'transport', 'at': '2026-10-22T08:00:00.000Z', 'projectId': 3, 'companyId': null});
  });

  test('every activity survives JSON, and an unknown one is refused', () {
    for (final kind in ActivityKind.values) {
      expect(ActivityKind.fromWire(kind.wireName), kind);
    }
    expect(() => ActivityKind.fromWire('lunch'), throwsFormatException);
  });

  test('a time without an offset is refused', () {
    expect(() => SwitchActivityRequest.fromJson({'kind': 'work', 'at': '2026-10-22T08:00:00'}), throwsFormatException);
  });
}
