import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/7/employees/5/remove';

TestApp _app({bool allow = true, int devUserId = 9}) {
  final app = TestApp(devUserId: devUserId, activeUserIds: {devUserId}, allowPermissions: allow);
  app.companies.existingIds = {7, 8};
  app.employees.members = {(7, 5), (7, 9)};
  return app;
}

/// "Remove employee" (Figma 238:3853): hidden from the interface, kept in the
/// database as MFD (product owner, 2026-10-21).
void main() {
  test('204: marks the employee for deletion and audits it, in one transaction', () async {
    final app = _app();

    final response = await app.post(_path, '');

    expect(response.statusCode, 204);
    expect(app.employees.removed, {5});
    expect(app.employees.writes, ['markRemoved 5'], reason: 'one UPDATE; nothing is deleted');
    expect(app.transactions.outcomes, ['commit']);
    final event = app.audit.events.single;
    expect(event.type, AuditEventType.employeeRemoved);
    expect(event.actorUserId, 9);
    expect(event.references, {EventLogReference.user: 5, EventLogReference.company: 7});
    expect(app.permissions.checked.single, (9, Permission.removeEmployee, 7));
  });

  test('already removed: 404, no second audit entry', () async {
    final app = _app();
    await app.post(_path, '');

    final again = await app.post(_path, '');

    expect(again.statusCode, 404);
    expect(app.audit.events, hasLength(1));
    expect(app.transactions.outcomes.last, 'rollback');
  });

  test('another company, an unknown company or an employee not in it is 404; nothing written', () async {
    final app = _app();

    expect((await app.post('/companies/8/employees/5/remove', '')).statusCode, 404);
    expect((await app.post('/companies/99/employees/5/remove', '')).statusCode, 404);
    expect((await app.post('/companies/7/employees/6/remove', '')).statusCode, 404);
    expect(app.employees.removed, isEmpty);
    expect(app.audit.events, isEmpty);
  });

  test('403 without the right, and nobody can remove their own account', () async {
    final noRight = _app(allow: false);
    expect((await noRight.post(_path, '')).statusCode, 403);
    expect(noRight.employees.removed, isEmpty);

    final self = _app(devUserId: 5);
    expect((await self.post(_path, '')).statusCode, 403);
    expect(self.employees.removed, isEmpty);
  });
}
