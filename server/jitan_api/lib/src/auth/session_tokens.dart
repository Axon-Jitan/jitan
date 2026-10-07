import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What a valid session token says.
class SessionClaims {
  const SessionClaims({
    required this.userId,
    required this.deviceId,
    required this.issuedAt,
    required this.expiresAt,
    required this.passwordFingerprint,
  });

  final int userId;

  /// The device the session was created on (app-generated, kept in its
  /// secure storage). Identifies the device; it is not persisted server-side
  /// because the ERD has no device table (GAP-05).
  final String deviceId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// Keyed fingerprint of the password hash at issue time. When the password
  /// changes, the fingerprint no longer matches and every session ends.
  final String passwordFingerprint;
}

/// A freshly issued session.
class IssuedSession {
  const IssuedSession({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  @override
  String toString() => 'IssuedSession(<redacted>, expires $expiresAt)';
}

/// Issues and verifies stateless session tokens (JWS compact, HS256).
///
/// Stateless because the ERD has no session table (GAP-05). Revocation
/// without storage: each token carries a fingerprint of the user's password
/// hash, so a password change signs out every device. Per-device revocation
/// and a list of signed-in devices need GAP-05 resolved.
///
/// The secret never leaves the server; tokens, hashes and fingerprints are
/// never logged.
class SessionTokens {
  SessionTokens({required String secret, required this.lifetime, DateTime Function()? clock})
      : _key = utf8.encode(secret),
        _clock = clock ?? DateTime.now;

  /// Development only: a random secret. Sessions end when the server restarts.
  factory SessionTokens.withRandomSecret({required Duration lifetime}) {
    final random = Random.secure();
    return SessionTokens(
      secret: base64Url.encode(List<int>.generate(48, (_) => random.nextInt(256))),
      lifetime: lifetime,
    );
  }

  final List<int> _key;
  final Duration lifetime;
  final DateTime Function() _clock;

  static const _header = {'alg': 'HS256', 'typ': 'JWT'};

  IssuedSession issue({required int userId, required String deviceId, required String passwordHash}) {
    final now = _clock().toUtc();
    final expiresAt = now.add(lifetime);
    final payload = {
      'sub': '$userId',
      'did': deviceId,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      'pwf': passwordFingerprint(passwordHash),
    };
    final signingInput = '${_b64Json(_header)}.${_b64Json(payload)}';
    return IssuedSession(token: '$signingInput.${_b64(_sign(signingInput))}', expiresAt: expiresAt);
  }

  /// The claims of [token], or `null` when it is malformed, not signed by
  /// this server, uses another algorithm, or has expired.
  SessionClaims? verify(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final header = _json(parts[0]);
      if (header['alg'] != 'HS256') return null;
      if (!_constantTimeEquals(_unb64(parts[2]), _sign('${parts[0]}.${parts[1]}'))) return null;

      final payload = _json(parts[1]);
      final userId = int.tryParse('${payload['sub']}');
      final deviceId = payload['did'];
      final iat = payload['iat'];
      final exp = payload['exp'];
      final pwf = payload['pwf'];
      if (userId == null || deviceId is! String || iat is! int || exp is! int || pwf is! String) return null;

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      if (!_clock().toUtc().isBefore(expiresAt)) return null;
      return SessionClaims(
        userId: userId,
        deviceId: deviceId,
        issuedAt: DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true),
        expiresAt: expiresAt,
        passwordFingerprint: pwf,
      );
    } on FormatException {
      return null;
    }
  }

  /// A keyed (HMAC) fingerprint of a password hash: reveals nothing about the
  /// hash, changes whenever it changes.
  String passwordFingerprint(String passwordHash) =>
      _b64(Hmac(sha256, _key).convert(utf8.encode('pwf:$passwordHash')).bytes.sublist(0, 16));

  List<int> _sign(String input) => Hmac(sha256, _key).convert(utf8.encode(input)).bytes;

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
