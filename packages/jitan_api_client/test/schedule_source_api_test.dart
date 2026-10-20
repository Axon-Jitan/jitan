import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('reads and sets which group an employee\'s schedule comes from, company-scoped', () async {
    final requests = <http.Request>[];
    final api = ScheduleSourceApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode(const ScheduleSourceResponse(
            groups: [GroupSummary(id: 1, name: 'White collar'), GroupSummary(id: 2, name: 'Blue collar')],
            sourceGroupId: 2,
          ).toJson()),
          200,
        );
      }),
    ));

    expect((await api.get(1, 5)).sourceGroupId, 2);
    await api.set(1, 5, 2);

    expect([for (final r in requests) '${r.method} ${r.url.path}'], [
      'GET /companies/1/employees/5/assignments/schedule-source',
      'PUT /companies/1/employees/5/assignments/schedule-source',
    ]);
    expect(jsonDecode(requests.last.body), {'groupId': 2});
  });
}
