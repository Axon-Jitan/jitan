import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:jitan_models/jitan_models.dart';

/// What a correctly signed temporary QR says.
class TemporaryQrClaims {
  const TemporaryQrClaims({
    required this.userId,
    required this.purpose,
    required this.tokenId,
    required this.issuedAt,
    required this.expiresAt,
  });

  final int userId;
  final TemporaryQrPurpose purpose;

  /// Random, unique per QR (`jti`): what the temporary store tracks.
  final String tokenId;
  final DateTime issuedAt;
  final DateTime expiresAt;
}

/// The result of checking a scanned value.
sealed class TemporaryQrCheck {
  const TemporaryQrCheck();
}

/// Signed by this server and not expired.
final class ValidTemporaryQr extends TemporaryQrCheck {
  const ValidTemporaryQr(this.claims);

  final TemporaryQrClaims claims;
}

/// Signed by this server but past its expiry.
final class ExpiredTemporaryQr extends TemporaryQrCheck {
  const ExpiredTemporaryQr(this.claims);

  final TemporaryQrClaims claims;
}

/// Not a temporary QR of this server: malformed, another algorithm or type,
/// or a bad signature.
final class InvalidTemporaryQr extends TemporaryQrCheck {
  const InvalidTemporaryQr();
}

/// A freshly issued QR value and what it says.
class IssuedTemporaryQr {
  const IssuedTemporaryQr({required this.token, required this.claims});

  final String token;
  final TemporaryQrClaims claims;

  @override
  String toString() => 'IssuedTemporaryQr(<redacted>, ${claims.purpose.wireName}, expires ${claims.expiresAt})';
}

/// Signs and checks temporary QR values (IT decision 2026-10-08): JWS
/// compact, HMAC-SHA256 (`package:crypto`), header type `jitan-temp-qr`, with
/// `sub` (userID), `pur` (purpose), `iat`, `exp` and a random 128-bit `jti`.
///
/// The signature makes a QR unforgeable and its claims trustworthy; whether
/// it is still the current one and unused is the [TemporaryTokenStore]'s
/// job. The key never leaves the server; QR values are never logged.
class TemporaryQrTokens {
  TemporaryQrTokens({
    required List<int> key,
    this.lifetime = defaultLifetime,
    DateTime Function()? clock,
    Random? random,
  })  : _key = List.unmodifiable(key),
        _clock = clock ?? DateTime.now,
        _random = random ?? Random.secure();

  /// A random 48-byte key for this process. Enough while the token state is
  /// in memory (a restart forgets every outstanding QR anyway); several API
  /// instances would need a shared key together with a shared store.
  factory TemporaryQrTokens.withRandomKey({Duration lifetime = defaultLifetime, DateTime Function()? clock}) {
    final random = Random.secure();
    return TemporaryQrTokens(
      key: List<int>.generate(48, (_) => random.nextInt(256)),
      lifetime: lifetime,
      clock: clock,
    );
  }

  /// IT decision 2026-10-08.
  static const defaultLifetime = Duration(minutes: 10);

  static const _type = 'jitan-temp-qr';
  static const _header = {'alg': 'HS256', 'typ': _type};
  static const _tokenIdBytes = 16;

  /// Longest value checked at all, as a cheap bound on untrusted input.
  static const maxLength = 1024;

  final List<int> _key;
  final Duration lifetime;
  final DateTime Function() _clock;
  final Random _random;

  IssuedTemporaryQr issue(int userId, TemporaryQrPurpose purpose) {
    final now = _clock().toUtc();
    final claims = TemporaryQrClaims(
      userId: userId,
      purpose: purpose,
      tokenId: _b64(List<int>.generate(_tokenIdBytes, (_) => _random.nextInt(256))),
      issuedAt: _seconds(now),
      expiresAt: _seconds(now.add(lifetime)),
    );
    final payload = {
      'sub': '$userId',
      'pur': purpose.wireName,
      'jti': claims.tokenId,
      'iat': claims.issuedAt.millisecondsSinceEpoch ~/ 1000,
      'exp': claims.expiresAt.millisecondsSinceEpoch ~/ 1000,
    };
    final signingInput = '${_b64Json(_header)}.${_b64Json(payload)}';
    return IssuedTemporaryQr(token: '$signingInput.${_b64(_sign(signingInput))}', claims: claims);
  }

  TemporaryQrCheck check(String value) {
    if (value.isEmpty || value.length > maxLength) return const InvalidTemporaryQr();
    final parts = value.split('.');
    if (parts.length != 3) return const InvalidTemporaryQr();
    try {
      final header = _json(parts[0]);
      if (header['alg'] != 'HS256' || header['typ'] != _type) return const InvalidTemporaryQr();
      if (!_constantTimeEquals(_unb64(parts[2]), _sign('${parts[0]}.${parts[1]}'))) return const InvalidTemporaryQr();

      final payload = _json(parts[1]);
      final userId = int.tryParse('${payload['sub']}');
      final purpose = TemporaryQrPurpose.fromWire(payload['pur'] as String?);
      final tokenId = payload['jti'];
      final iat = payload['iat'];
      final exp = payload['exp'];
      if (userId == null || purpose == null || tokenId is! String || tokenId.isEmpty || iat is! int || exp is! int) {
        return const InvalidTemporaryQr();
      }
      final claims = TemporaryQrClaims(
        userId: userId,
        purpose: purpose,
        tokenId: tokenId,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      );
      return _clock().toUtc().isBefore(claims.expiresAt) ? ValidTemporaryQr(claims) : ExpiredTemporaryQr(claims);
    } on FormatException {
      return const InvalidTemporaryQr();
    } on TypeError {
      return const InvalidTemporaryQr();
    }
  }

  List<int> _sign(String input) => Hmac(sha256, _key).convert(utf8.encode(input)).bytes;

  static DateTime _seconds(DateTime t) => DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);

  static String _b64Json(Map<String, Object?> value) => _b64(utf8.encode(jsonEncode(value)));

  static Map<String, Object?> _json(String part) {
    final decoded = jsonDecode(utf8.decode(_unb64(part)));
    if (decoded is Map<String, Object?>) return decoded;
    throw const FormatException('Not a JSON object.');
  }

  static String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String text) => base64Url.decode(text.padRight((text.length + 3) ~/ 4 * 4, '='));

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
