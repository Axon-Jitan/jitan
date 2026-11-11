import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _deactivate = '/companies/7/employees/5/deactivate';
const _reactivate = '/companies/7/employees/5/reactivate';

TestApp _app({bool allow = true, int devUserId = 9}) {
  final app = TestApp(devUserId: devUserId, activeUserIds: {devUserId}, allowPermissions: allow);
  app.companies.existingIds = {7, 8};
  app.employees.members = {(7, 5), (7, 9)};
  return app;
}

/// Deactivate / Reactivate an employee (Figma 1534:366, 1534:188): reversible,
/// in every company; replaces Remove (product owner, 2026-11-11).
void main() {
  test('deactivate: 204, switches the employee off and audits it, in one transaction', () async {
    final app = _app();

    final response = await app.post(_deactivate, '');

    expect(response.statusCode, 204);
    expect(app.employees.inactive, {5});
    expect(app.employees.writes, ['deactivate 5'], reason: 'one UPDATE; nothing is deleted');
    expect(app.transactions.outcomes, ['commit']);
    final event = app.audit.events.single;
    expect(event.type, AuditEventType.employeeDeactivated);
    expect(event.actorUserId, 9);
    expect(event.references, {EventLogReference.user: 5, EventLogReference.company: 7});
    expect(app.permissions.checked.single, (9, Permission.changeEmployeeStatus, 7));
  });

  test('reactivate undoes it, audited as reactivated', () async {
    final app = _app();
    await app.post(_deactivate, '');

    final response = await app.post(_reactivate, '');

    expect(response.statusCode, 204);
    expect(app.employees.inactive, isEmpty);
    expect(app.audit.events.map((e) => e.type), [AuditEventType.employeeDeactivated, AuditEventType.employeeReactivated]);
  });

  test('already so: 404, no second audit entry', () async {
    final app = _app();
    await app.post(_deactivate, '');

    expect((await app.post(_deactivate, '')).statusCode, 404);
    expect((await _app().post(_reactivate, '')).statusCode, 404, reason: 'an active employee');
    expect(app.audit.events, hasLength(1));
    expect(app.transactions.outcomes.last, 'rollback');
  });

  test('another company, an unknown company or an employee not in it is 404; nothing written', () async {
    final app = _app();

    expect((await app.post('/companies/8/employees/5/deactivate', '')).statusCode, 404);
    expect((await app.post('/companies/99/employees/5/deactivate', '')).statusCode, 404);
    expect((await app.post('/companies/7/employees/6/deactivate', '')).statusCode, 404);
    expect(app.employees.inactive, isEmpty);
    expect(app.audit.events, isEmpty);
  });

  test('403 without the right, and nobody can deactivate their own account', () async {
    final noRight = _app(allow: false);
    expect((await noRight.post(_deactivate, '')).statusCode, 403);
    expect(noRight.employees.inactive, isEmpty);

    final self = _app(devUserId: 5);
    expect((await self.post(_deactivate, '')).statusCode, 403);
    expect(self.employees.inactive, isEmpty);
  });

  test('Remove is gone: its path answers 404', () async {
    expect((await _app().post('/companies/7/employees/5/remove', '')).statusCode, 404);
  });
}
