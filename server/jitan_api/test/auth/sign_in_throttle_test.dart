import 'package:jitan_api/src/auth/hashing_slots.dart';
import 'package:jitan_api/src/auth/sign_in_throttle.dart';
import 'package:jitan_api/src/http/api_exception.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late SignInThrottle throttle;

  setUp(() {
    now = DateTime(2026, 10, 31, 9);
    throttle = SignInThrottle(clock: () => now);
  });

  /// [times] attempts that all fail, one after the other.
  void fail(String code, [int times = SignInThrottle.maxFailures]) {
    for (var i = 0; i < times; i++) {
      expect(throttle.begin(code), isTrue, reason: 'attempt ${i + 1}');
      throttle.failed(code);
    }
  }

  bool allowed(String code) {
    final ok = throttle.begin(code);
    if (ok) throttle.succeeded(code);
    return ok;
  }

  test('four failures: still allowed; the fifth blocks', () {
    fail('SBW', 4);
    expect(throttle.begin('SBW'), true);
    throttle.failed('SBW');

    expect(throttle.begin('SBW'), false);
  });

  test('upper case, spaces and accents are the same code (review M2)', () {
    fail('EMPÉ01');

    expect(throttle.begin(' empe01 '), false);
    expect(throttle.begin('EMPÈ01'), false);
  });

  test('guesses sent in parallel share the same five attempts (review M2)', () {
    final started = [for (var i = 0; i < 20; i++) throttle.begin('SBW')];

    expect(started.where((ok) => ok), hasLength(SignInThrottle.maxFailures));
  });

  test('another code is not affected', () {
    fail('SBW');

    expect(allowed('KDV'), true);
  });

  test('the block ends after the window', () {
    fail('SBW');

    now = now.add(SignInThrottle.window - const Duration(seconds: 1));
    expect(throttle.begin('SBW'), false);

    now = now.add(const Duration(seconds: 1));
    expect(allowed('SBW'), true);
  });

  test('old failures no longer count', () {
    fail('SBW', 4);
    now = now.add(SignInThrottle.window);

    fail('SBW', 1);

    expect(allowed('SBW'), true);
  });

  test('signing in clears the count', () {
    fail('SBW', 4);

    expect(allowed('SBW'), true);
    fail('SBW', 4);

    expect(allowed('SBW'), true);
  });

  test('a flood of made-up codes never frees a blocked code (review M2)', () {
    fail('SBW');
    for (var i = 0; i < SignInThrottle.maxTracked * 2; i++) {
      if (throttle.begin('code$i')) throttle.failed('code$i');
    }

    expect(throttle.begin('SBW'), false);
  });

  group('hashing slots (review M2)', () {
    test('no more than the limit at once; the rest wait their turn', () async {
      final slots = HashingSlots(limit: 2);
      var most = 0;
      Future<void> work() => slots.run(() async {
        most = most > slots.running ? most : slots.running;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      await Future.wait([for (var i = 0; i < 6; i++) work()]);

      expect(most, 2);
      expect(slots.running, 0);
    });

    test('waiting too long answers busy (503)', () async {
      final slots = HashingSlots(limit: 1, maxWait: const Duration(milliseconds: 30));
      final long = slots.run(() => Future<void>.delayed(const Duration(milliseconds: 200)));

      await expectLater(slots.run(() async {}), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
      await long;
    });
  });
}
