import 'dart:async';
import 'dart:convert';

import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/temporary_qr/in_memory_temporary_token_store.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_service.dart';
import 'package:jitan_api/src/temporary_qr/temporary_qr_tokens.dart';
import 'package:jitan_api/src/temporary_qr/temporary_token_store.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

const _onboarding = TemporaryQrPurpose.onboarding;
const _recovery = TemporaryQrPurpose.recovery;

Matcher _apiError(int status, String code) =>
    throwsA(isA<ApiException>().having((e) => (e.statusCode, e.code), 'status, code', (status, code)));

/// A store whose next [consume] fails, like a shared cache that is briefly
/// unreachable after MySQL committed.
class _FlakyStore implements TemporaryTokenStore {
  _FlakyStore(this._inner);

  final TemporaryTokenStore _inner;
  var failNextConsume = false;

  @override
  Future<TemporaryTokenState> claim(TemporaryTokenKey key, String tokenId, String deviceId) =>
      _inner.claim(key, tokenId, deviceId);

  @override
  Future<void> consume(TemporaryTokenKey key, String tokenId, String deviceId) async {
    if (failNextConsume) {
      failNextConsume = false;
      throw StateError('cache unavailable');
    }
    await _inner.consume(key, tokenId, deviceId);
  }

  @override
  Future<TemporaryTokenState> inspect(TemporaryTokenKey key, String tokenId, {String? deviceId}) =>
      _inner.inspect(key, tokenId, deviceId: deviceId);

  @override
  Future<void> release(TemporaryTokenKey key, String tokenId, String deviceId) => _inner.release(key, tokenId, deviceId);

  @override
  Future<void> replace(TemporaryTokenKey key, String tokenId, DateTime expiresAt) => _inner.replace(key, tokenId, expiresAt);
}

void main() {
  var now = DateTime.utc(2026, 10, 8, 12);
  DateTime clock() => now;
  setUp(() => now = DateTime.utc(2026, 10, 8, 12));

  TemporaryQrTokens tokens([List<int>? key]) => TemporaryQrTokens(key: key ?? List.filled(32, 7), clock: clock);

  group('TemporaryQrTokens (signed payload)', () {
    test('carries employee, purpose, 10-minute expiry and a random id', () {
      final a = tokens().issue(3, _onboarding);
      final b = tokens().issue(3, _onboarding);

      final claims = (tokens().check(a.token) as ValidTemporaryQr).claims;
      expect((claims.userId, claims.purpose), (3, _onboarding));
      expect(claims.expiresAt, now.add(const Duration(minutes: 10)));
      expect(a.claims.tokenId, isNot(b.claims.tokenId));
      expect(base64Url.decode(a.claims.tokenId.padRight(24, '=')), hasLength(16), reason: '128 random bits');
      expect(a.toString(), isNot(contains(a.token)));
    });

    test('expired after 10 minutes', () {
      final issued = tokens().issue(3, _onboarding);
      now = now.add(const Duration(minutes: 10));

      expect(tokens().check(issued.token), isA<ExpiredTemporaryQr>());
    });

    test('a changed payload, another key, another token type or garbage is invalid', () {
      final issued = tokens().issue(3, _onboarding);
      final [header, payload, signature] = issued.token.split('.');
      final forged = base64Url
          .encode(utf8.encode(utf8.decode(base64Url.decode(payload.padRight((payload.length + 3) ~/ 4 * 4, '='))).replaceFirst('"3"', '"4"')))
          .replaceAll('=', '');

      expect(tokens().check('$header.$forged.$signature'), isA<InvalidTemporaryQr>());
      expect(tokens(List.filled(32, 8)).check(issued.token), isA<InvalidTemporaryQr>());
      expect(tokens().check('${base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}')).replaceAll('=', '')}.$payload.$signature'),
          isA<InvalidTemporaryQr>());
      for (final value in ['', 'abc', 'a.b.c', 'x' * 2000, 'Zk3Q9X0mRk2a1b2c3d4e5f6g']) {
        expect(tokens().check(value), isA<InvalidTemporaryQr>(), reason: value);
      }
    });
  });

  group('TemporaryQrService', () {
    late InMemoryTemporaryTokenStore store;
    late TemporaryQrService service;
    setUp(() {
      store = InMemoryTemporaryTokenStore(clock: clock);
      service = TemporaryQrService(tokens: tokens(), store: store);
    });

    Future<bool> redeem(String qr, String device, {TemporaryQrPurpose purpose = _onboarding}) =>
        service.redeem(qr, purpose, device, (claims, {required isRetry}) async => isRetry);

    test('a valid QR is accepted on scan without being used up', () async {
      final issued = await service.issue(3, _onboarding);

      expect((await service.check(issued.token, _onboarding)).userId, 3);
      expect((await service.check(issued.token, _onboarding)).userId, 3, reason: 'scanning twice is fine');
    });

    test('expired is refused (410 qr_expired)', () async {
      final issued = await service.issue(3, _onboarding);
      now = now.add(const Duration(minutes: 11));

      expect(service.check(issued.token, _onboarding), _apiError(410, ApiErrorCode.qrExpired));
      expect(redeem(issued.token, 'd1'), _apiError(410, ApiErrorCode.qrExpired));
    });

    test('invalid signature is refused (400 invalid_qr_code)', () async {
      final foreign = tokens(List.filled(32, 9)).issue(3, _onboarding);

      expect(service.check(foreign.token, _onboarding), _apiError(400, ApiErrorCode.invalidQrCode));
    });

    test('never accepted for another purpose, even before expiry checks', () async {
      final recovery = await service.issue(3, _recovery);

      expect(service.check(recovery.token, _onboarding), _apiError(400, ApiErrorCode.qrWrongPurpose));
      expect(redeem(recovery.token, 'd1'), _apiError(400, ApiErrorCode.qrWrongPurpose));
      expect(await redeem(recovery.token, 'd1', purpose: _recovery), isFalse, reason: 'still valid for its purpose');
    });

    test('regenerating invalidates the previous QR', () async {
      final first = await service.issue(3, _onboarding);
      final second = await service.issue(3, _onboarding);

      expect(service.check(first.token, _onboarding), _apiError(410, ApiErrorCode.qrExpired));
      expect(await redeem(second.token, 'd1'), isFalse);
    });

    test('one onboarding and one recovery QR are tracked separately', () async {
      final onboarding = await service.issue(3, _onboarding);
      await service.issue(3, _recovery);

      expect((await service.check(onboarding.token, _onboarding)).userId, 3);
    });

    test('used once: another device and later scans are refused (409 qr_already_used)', () async {
      final issued = await service.issue(3, _onboarding);
      await redeem(issued.token, 'd1');

      expect(redeem(issued.token, 'd2'), _apiError(409, ApiErrorCode.qrAlreadyUsed));
      expect(service.check(issued.token, _onboarding), _apiError(409, ApiErrorCode.qrAlreadyUsed));
    });

    test('concurrent redeems from two devices: exactly one runs the work', () async {
      final issued = await service.issue(3, _onboarding);
      var runs = 0;
      final gate = Completer<void>();
      Future<Object?> attempt(String device) => service
          .redeem(issued.token, _onboarding, device, (claims, {required isRetry}) async {
            runs++;
            await gate.future;
            return null;
          })
          .then<Object?>((_) => 'ok', onError: (Object e) => e);

      final results = Future.wait([attempt('d1'), attempt('d2')]);
      gate.complete();

      expect((await results).whereType<ApiException>().map((e) => e.code), [ApiErrorCode.qrAlreadyUsed]);
      expect(runs, 1);
    });

    test('a refused completion gives the QR back', () async {
      final issued = await service.issue(3, _onboarding);

      await expectLater(
        service.redeem(issued.token, _onboarding, 'd1', (c, {required isRetry}) async => throw const ApiException.badRequest('weak password')),
        throwsA(isA<ApiException>()),
      );

      expect(await redeem(issued.token, 'd2'), isFalse, reason: 'released: usable again');
    });

    test('interrupted after the work: only the same device may retry, flagged as a retry', () async {
      final flaky = _FlakyStore(store)..failNextConsume = true;
      final service = TemporaryQrService(tokens: tokens(), store: flaky);
      final issued = await service.issue(3, _onboarding);
      final retries = <bool>[];
      Future<void> run(String device) =>
          service.redeem(issued.token, _onboarding, device, (c, {required isRetry}) async => retries.add(isRetry));

      await expectLater(run('d1'), throwsA(isA<StateError>()));
      await expectLater(run('d2'), _apiError(409, ApiErrorCode.qrAlreadyUsed));
      await run('d1');
      await run('d1');

      expect(retries, [false, true, true], reason: 'the same device can always finish');
    });

    test('a crash before the work committed keeps the claim for that device only', () async {
      final issued = await service.issue(3, _onboarding);

      await expectLater(
        service.redeem(issued.token, _onboarding, 'd1', (c, {required isRetry}) async => throw StateError('db down')),
        throwsA(isA<StateError>()),
      );

      expect(redeem(issued.token, 'd2'), _apiError(409, ApiErrorCode.qrAlreadyUsed));
      expect(await redeem(issued.token, 'd1'), isTrue);
    });

    test('the store keeps only small entries and forgets them at expiry', () async {
      await service.issue(3, _onboarding);
      await service.issue(4, _recovery);
      expect(store.length, 2);

      now = now.add(const Duration(minutes: 10));

      expect(store.length, 0);
    });
  });
}
