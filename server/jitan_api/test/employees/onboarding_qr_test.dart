import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _path = '/companies/7/employees/1/onboarding-qr';

TestApp _app({String? existingQr = 'EXISTING-QR', bool allow = true}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.existingIds = {7, 8};
  app.employees.qrCodes = {(7, 1): existingQr};
  return app;
}

void main() {
  group('POST /companies/{id}/employees/{userId}/onboarding-qr', () {
    test('returns the stored personal QR unchanged, with no write and no audit', () async {
      final app = _app();

      final response = await app.post(_path, '');

      expect(response.statusCode, 200);
      expect(await jsonBody(response), {'qrCode': 'EXISTING-QR'});
      expect(app.employees.writes, isEmpty);
      expect(app.audit.events, isEmpty);
    });

    test('the response is never cached (the value is a credential)', () async {
      final response = await _app().post(_path, '');

      expect(response.headers['cache-control'], 'no-store');
    });

    test('an employee without a QR gets a new random one, stored once and audited', () async {
      final app = _app(existingQr: null);

      final first = await jsonBody(await app.post(_path, ''));
      final second = await jsonBody(await app.post(_path, ''));

      expect(first, {'qrCode': 'QR-1'}, reason: 'from the secure generator, not from IDs');
      expect(second, first, reason: 'stable: the same QR every time afterwards');
      expect(app.employees.writes, ['setQr 1']);
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.personalQrGenerated);
      expect(event.actorUserId, 9);
      expect(event.references, {EventLogReference.user: 1, EventLogReference.company: 7});
      expect(app.transactions.outcomes, ['commit', 'commit']);
    });

    test('if another request stored a QR first, that one is returned and nothing is audited', () async {
      final app = _app(existingQr: null)..employees.loseQrRace = true;

      final body = await jsonBody(await app.post(_path, ''));

      expect(body, {'qrCode': 'QR-OTHER'});
      expect(app.audit.events, isEmpty);
    });

    test('checks viewEmployeeQr for that company before reading anything', () async {
      final app = _app(allow: false);

      final response = await app.post(_path, '');

      expect(response.statusCode, 403);
      expect(app.permissions.checked, [(9, Permission.viewEmployeeQr, 7)]);
    });

    test('404 for a user outside the company, an unknown employee or company', () async {
      final app = _app();

      expect((await app.post('/companies/8/employees/1/onboarding-qr', '')).statusCode, 404);
      expect((await app.post('/companies/7/employees/2/onboarding-qr', '')).statusCode, 404);
      expect((await app.post('/companies/99/employees/1/onboarding-qr', '')).statusCode, 404);
    });
  });
}
