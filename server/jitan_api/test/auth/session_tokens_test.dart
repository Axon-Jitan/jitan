import 'dart:convert';

import 'package:jitan_api/src/auth/session_tokens.dart';
import 'package:test/test.dart';

void main() {
  var now = DateTime.utc(2026, 10, 7, 12);
  SessionTokens tokens({String secret = 'test-secret-that-is-long-enough-123456'}) =>
      SessionTokens(secret: secret, lifetime: const Duration(days: 30), clock: () => now);

  setUp(() => now = DateTime.utc(2026, 10, 7, 12));

  test('issues a token that verifies to its claims', () {
    final session = tokens().issue(userId: 42, deviceId: 'device-abc-123', passwordHash: r'$argon2id$hash');

    final claims = tokens().verify(session.token)!;

    expect(claims.userId, 42);
    expect(claims.deviceId, 'device-abc-123');
    expect(claims.expiresAt, DateTime.utc(2026, 11, 6, 12));
    expect(session.expiresAt, claims.expiresAt);
    expect(claims.passwordFingerprint, tokens().passwordFingerprint(r'$argon2id$hash'));
  });

  test('the token never contains the password hash', () {
    final session = tokens().issue(userId: 1, deviceId: 'd' * 16, passwordHash: r'$argon2id$SECRETHASH');
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(session.token.split('.')[1])));

    expect(payload, isNot(contains('SECRETHASH')));
    expect(session.toString(), isNot(contains(session.token)));
  });

  test('rejects expired, tampered, foreign and malformed tokens', () {
    final session = tokens().issue(userId: 42, deviceId: 'device-abc-123', passwordHash: 'h');
    final [header, payload, signature] = session.token.split('.');

    final otherUser = base64Url
        .encode(utf8.encode(jsonEncode({'sub': '1', 'did': 'x', 'iat': 0, 'exp': 9999999999, 'pwf': 'p'})))
        .replaceAll('=', '');
    expect(tokens().verify('$header.$otherUser.$signature'), isNull, reason: 'payload swapped');
    expect(tokens(secret: 'another-secret-that-is-long-enough-xyz').verify(session.token), isNull);
    expect(tokens().verify('$header.$payload.${signature}x'), isNull);
    expect(tokens().verify('garbage'), isNull);
    expect(tokens().verify(''), isNull);

    final none = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'}))).replaceAll('=', '');
    expect(tokens().verify('$none.$payload.'), isNull, reason: 'alg=none');

    now = now.add(const Duration(days: 30));
    expect(tokens().verify(session.token), isNull, reason: 'expired');
  });

  test('a password change gives a different fingerprint', () {
    expect(tokens().passwordFingerprint('hash-1'), isNot(tokens().passwordFingerprint('hash-2')));
  });
}
