import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

void main() {
  test('GET /groups lists assignable groups, checking viewGroups', () async {
    final app = TestApp(devUserId: 9, activeUserIds: {9});
    app.groups.groups = const [GroupSummary(id: 1, name: 'Blue collar'), GroupSummary(id: 2, name: 'White collar')];

    final response = await app.get('/groups');

    expect(response.statusCode, 200);
    expect(await jsonBody(response), {
      'groups': [
        {'id': 1, 'name': 'Blue collar'},
        {'id': 2, 'name': 'White collar'},
      ],
    });
    expect(app.permissions.checked, [(9, Permission.viewGroups, null)]);
  });

  test('GET /groups is forbidden without the permission', () async {
    final app = TestApp(allowPermissions: false);

    expect((await app.get('/groups')).statusCode, 403);
  });
}
