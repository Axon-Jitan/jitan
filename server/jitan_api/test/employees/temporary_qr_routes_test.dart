import 'package:jitan_api/src/audit/audit_event.dart';
import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

const _onboardingPath = '/companies/7/employees/1/onboarding-qr';
const _recoveryPath = '/companies/7/employees/1/recovery-qr';

/// HR user 9 in company 7; employee 1 is a member who has not set a password.
TestApp _app({bool allow = true, bool active = true, bool activated = false}) {
  final app = TestApp(devUserId: 9, activeUserIds: {9}, allowPermissions: allow);
  app.companies.existingIds = {7, 8};
  app.employees.members = {(7, 1)};
  app.employees.memberStates = {1: (isActive: active, isActivated: activated)};
  app.onboarding.users = {1: (userId: 1, firstName: 'Disan', lastName: 'Ssebowa', code: 'SBW', isActive: active)};
  return app;
}

Future<TemporaryQrResponse> _qr(TestApp app, String path) async {
  final response = await app.post(path, '');
  expect(response.statusCode, 200);
  return TemporaryQrResponse.fromJson(await jsonBody(response));
}

void main() {
  group('POST …/onboarding-qr and …/recovery-qr (HR/Admin)', () {
    test('a temporary onboarding QR: purpose, 10-minute expiry, never cached, generation audited', () async {
      final app = _app();

      final response = await app.post(_onboardingPath, '');
      final qr = TemporaryQrResponse.fromJson(await jsonBody(response));

      expect(response.headers['cache-control'], 'no-store');
      expect(qr.purpose, TemporaryQrPurpose.onboarding);
      expect(qr.expiresAt, app.now.toUtc().add(const Duration(minutes: 10)));
      final event = app.audit.events.single;
      expect(event.type, AuditEventType.onboardingQrGenerated);
      expect(event.actorUserId, 9);
      expect(event.references, {EventLogReference.user: 1, EventLogReference.company: 7});
      expect(app.employees.writes, isEmpty, reason: 'nothing stored in MySQL but the audit row');
    });

    test('generating again invalidates the previous QR', () async {
      final app = _app();
      final first = await _qr(app, _onboardingPath);
      final second = await _qr(app, _onboardingPath);

      expect(first.qrCode, isNot(second.qrCode));
      expect((await app.post('/onboarding/start', '{"qrCode": "${first.qrCode}"}')).statusCode, 410);
    });

    test('an onboarding QR only while the employee has not set a password', () async {
      final response = await _app(activated: true).post(_onboardingPath, '');

      expect(response.statusCode, 409);
      expect(await jsonBody(response), containsPair('error', containsPair('code', 'onboarding_already_completed')));
    });

    test('a recovery QR only after Reset account access (the HR-authorized recovery)', () async {
      final activated = await _app(activated: true).post(_recoveryPath, '');
      final neverActivated = await _app().post(_recoveryPath, '');
      final reset = _app()..onboarding.earlierAccessEvents[1] = 'employee.access.reset';

      for (final refused in [activated, neverActivated]) {
        expect(refused.statusCode, 409);
        expect(await jsonBody(refused), containsPair('error', containsPair('code', 'account_not_reset')));
      }
      final qr = await _qr(reset, _recoveryPath);
      expect(qr.purpose, TemporaryQrPurpose.recovery);
      expect(reset.audit.events.single.type, AuditEventType.recoveryQrGenerated);
    });

    test('no onboarding QR once access was reset: onboarding and recovery stay separate', () async {
      final app = _app()..onboarding.earlierAccessEvents[1] = 'employee.access.reset';

      final response = await app.post(_onboardingPath, '');

      expect(response.statusCode, 409);
      expect(await jsonBody(response), containsPair('error', containsPair('code', 'onboarding_already_completed')));
    });

    test('no password but no pending reset (cleared outside Jitan): neither QR, a configuration error', () async {
      final app = _app()..onboarding.earlierAccessEvents[1] = 'employee.onboarding.completed';

      expect((await app.post(_onboardingPath, '')).statusCode, 409);
      expect(await jsonBody(await app.post(_recoveryPath, '')), containsPair('error', containsPair('code', 'account_not_reset')));
    });

    test('not for a disabled employee', () async {
      final response = await _app(active: false).post(_onboardingPath, '');

      expect(response.statusCode, 409);
      expect(await jsonBody(response), containsPair('error', containsPair('code', 'account_inactive')));
    });

    test('company-scoped: permission in that company; another company\'s employee is 404', () async {
      final app = _app();
      await app.post(_onboardingPath, '');
      expect(app.permissions.checked.last, (9, Permission.issueTemporaryQr, 7));

      expect((await app.post('/companies/8/employees/1/onboarding-qr', '')).statusCode, 404);
      expect((await _app(allow: false).post(_recoveryPath, '')).statusCode, 403);
      expect(app.audit.events, hasLength(1));
    });
  });
}
