import 'package:jitan_api/src/auth/sign_in_throttle.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late SignInThrottle throttle;

  setUp(() {
    now = DateTime(2026, 10, 31, 9);
    throttle = SignInThrottle(clock: () => now);
  });

  void fail(String code, [int times = SignInThrottle.maxFailures]) {
    for (var i = 0; i < times; i++) {
      throttle.failed(code);
    }
  }

  test('four failures: still allowed; the fifth blocks', () {
    fail('SBW', 4);
    expect(throttle.isBlocked('SBW'), false);

    fail('SBW', 1);
    expect(throttle.isBlocked('SBW'), true);
  });

  test('upper case and spaces are the same code', () {
    fail('SBW');

    expect(throttle.isBlocked(' sbw '), true);
  });

  test('another code is not affected', () {
    fail('SBW');

    expect(throttle.isBlocked('KDV'), false);
  });

  test('the block ends after the window', () {
    fail('SBW');

    now = now.add(SignInThrottle.window - const Duration(seconds: 1));
    expect(throttle.isBlocked('SBW'), true);

    now = now.add(const Duration(seconds: 1));
    expect(throttle.isBlocked('SBW'), false);
  });

  test('old failures no longer count', () {
    fail('SBW', 4);
    now = now.add(SignInThrottle.window);

    fail('SBW', 1);

    expect(throttle.isBlocked('SBW'), false);
  });

  test('signing in clears the count', () {
    fail('SBW', 4);

    throttle.succeeded('SBW');
    fail('SBW', 4);

    expect(throttle.isBlocked('SBW'), false);
  });

  test('a flood of made-up codes keeps working and stays bounded', () {
    for (var i = 0; i < 20000; i++) {
      throttle.failed('code$i');
    }
    fail('SBW');

    expect(throttle.isBlocked('SBW'), true);
  });
}
