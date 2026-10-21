import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const fabian = GroupMember(
    id: 7,
    firstName: 'Fabian',
    lastName: 'Peeters',
    code: 'FPT',
    companies: ['Almeco'],
    groups: ['Drivers'],
  );

  test('lists, finds, adds and removes a group\'s members', () async {
    final requests = <http.Request>[];
    final api = GroupMembersApi(ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(const GroupMemberListResponse(members: [fabian]).toJson()), 200);
      }),
    ));

    final members = await api.members(5);
    await api.candidates(5, search: '  pee ');
    await api.candidates(5, search: ' ');
    await api.candidates(null, search: 'pee');
    await api.add(5, [7, 8], followIds: [8]);
    await api.remove(5, 7);

    expect(members.single.displayName, 'Fabian Peeters');
    expect(members.single.companies, ['Almeco']);
    expect([for (final r in requests) '${r.method} ${r.url}'], [
      'GET http://api.test/groups/5/members',
      'GET http://api.test/groups/5/candidates?search=pee',
      'GET http://api.test/groups/5/candidates',
      'GET http://api.test/groups/candidates?search=pee',
      'POST http://api.test/groups/5/members',
      'DELETE http://api.test/groups/5/members/7',
    ]);
    expect(jsonDecode(requests[4].body), {'ids': [7, 8], 'followIds': [8]});
  });
}
