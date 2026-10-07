import 'package:employee_mobile/src/config/employee_config.dart';
import 'package:employee_mobile/src/device/session_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_jitan_server.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7, 12);

  test('the device id is random, URL-safe, accepted by the server format, and stable', () async {
    final store = MemorySecureStore();
    final first = await SessionManager(store).deviceId();

    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{16,128}$')));
    expect(await SessionManager(store).deviceId(), first, reason: 'kept across app starts');
    expect(await SessionManager(MemorySecureStore()).deviceId(), isNot(first));
  });

  test('a saved session is restored until it expires', () async {
    final store = MemorySecureStore();
    await SessionManager(store, clock: () => now).save(SessionInfo(accessToken: 'tok', expiresAt: now.add(const Duration(days: 30))));

    final later = SessionManager(store, clock: () => now.add(const Duration(days: 29)));
    expect(await later.restore(), isTrue);
    expect(later.accessToken, 'tok');

    final expired = SessionManager(store, clock: () => now.add(const Duration(days: 31)));
    expect(await expired.restore(), isFalse);
    expect(expired.accessToken, isNull);
    expect(store.values.containsKey('session.token'), isFalse, reason: 'removed');
  });

  test('clear signs out but keeps the device id', () async {
    final store = MemorySecureStore();
    final session = SessionManager(store, clock: () => now);
    final id = await session.deviceId();
    await session.save(SessionInfo(accessToken: 'tok', expiresAt: now.add(const Duration(days: 1))));

    await session.clear();

    expect(session.isSignedIn, isFalse);
    expect(store.values.keys, unorderedEquals(['device.id', 'device.signedInBefore']), reason: 'no session left');
    expect(await session.hasSignedInBefore(), isTrue, reason: 'the next start opens sign-in, not onboarding');
    expect(await session.deviceId(), id);
  });

  test('config requires an absolute API URL', () {
    expect(EmployeeConfig.parse('https://jitan.example.com/api')?.apiBaseUri.toString(), 'https://jitan.example.com/api/');
    expect(EmployeeConfig.parse(''), isNull);
    expect(EmployeeConfig.parse('/api'), isNull);
  });
}
