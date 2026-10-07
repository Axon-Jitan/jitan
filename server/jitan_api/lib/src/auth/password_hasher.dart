import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Argon2id cost parameters.
class Argon2idParameters {
  const Argon2idParameters({required this.memoryKiB, required this.iterations, this.parallelism = 1});

  /// OWASP's recommended Argon2id configuration: 19 MiB, 2 iterations, 1 lane.
  /// About 140 ms per hash in the compiled server on the development machine
  /// (benchmark 2026-10-07). Re-run `tool/bench_argon2.dart` on the
  /// production VM and adjust through the environment if needed.
  static const recommended = Argon2idParameters(memoryKiB: 19456, iterations: 2);

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// Bounds accepted from configuration or from a stored hash, so a malformed
  /// value can never make the server allocate unbounded memory.
  static const minMemoryKiB = 8192;
  static const maxMemoryKiB = 1048576;
  static const maxIterations = 10;
  static const maxParallelism = 8;

  bool get isWithinBounds =>
      memoryKiB >= minMemoryKiB &&
      memoryKiB <= maxMemoryKiB &&
      iterations >= 1 &&
      iterations <= maxIterations &&
      parallelism >= 1 &&
      parallelism <= maxParallelism;

  @override
  bool operator ==(Object other) =>
      other is Argon2idParameters &&
      other.memoryKiB == memoryKiB &&
      other.iterations == iterations &&
      other.parallelism == parallelism;

  @override
  int get hashCode => Object.hash(memoryKiB, iterations, parallelism);

  @override
  String toString() => 'Argon2id(m=$memoryKiB KiB, t=$iterations, p=$parallelism)';
}

/// Hashes and verifies passwords for `tblUser.userPassword`. Server-side only.
///
/// Argon2id (RFC 9106), stored as the standard self-describing encoded
/// string `$argon2id$v=19$m=…,t=…,p=…$<salt>$<hash>`: a fresh 16-byte random
/// salt per password, 32-byte output. Because the parameters travel inside
/// each hash, they can be raised later and older hashes still verify
/// ([needsRehash] tells when to upgrade one after a successful sign-in). The
/// format is interoperable: libsodium and argon2-cffi verify these hashes,
/// and they verify theirs.
///
/// Work runs on a separate isolate so hashing never blocks other requests.
/// Never log a password or a hash.
class PasswordHasher {
  const PasswordHasher({this.parameters = Argon2idParameters.recommended});

  final Argon2idParameters parameters;

  static const _saltBytes = 16;
  static const _hashBytes = 32;
  static const _version = 19; // 0x13

  Future<String> hash(String password) {
    final p = parameters;
    final salt = _randomSalt();
    return Isolate.run(() => _encode(p, salt, _derive(password, salt, p)));
  }

  /// Whether [password] matches [encodedHash]. Anything that is not a
  /// well-formed Argon2id hash within bounds (e.g. a legacy bcrypt hash or a
  /// corrupted value) is a mismatch, never an error. Constant-time compare.
  Future<bool> verify(String password, String encodedHash) => Isolate.run(() {
        final decoded = _decode(encodedHash);
        if (decoded == null) return false;
        final actual = _derive(password, decoded.salt, decoded.parameters, length: decoded.hash.length);
        return _constantTimeEquals(actual, decoded.hash);
      });

  /// Whether [encodedHash] was made with weaker or different parameters than
  /// the current ones (or is not Argon2id), and should be re-hashed the next
  /// time the user proves their password.
  bool needsRehash(String encodedHash) => _decode(encodedHash)?.parameters != parameters;

  static Uint8List _derive(String password, Uint8List salt, Argon2idParameters p, {int length = _hashBytes}) {
    final generator = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          salt,
          desiredKeyLength: length,
          iterations: p.iterations,
          memory: p.memoryKiB,
          lanes: p.parallelism,
          version: Argon2Parameters.ARGON2_VERSION_13,
        ),
      );
    final out = Uint8List(length);
    generator.deriveKey(Uint8List.fromList(utf8.encode(password)), 0, out, 0);
    return out;
  }

  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(_saltBytes, (_) => random.nextInt(256)));
  }

  static String _encode(Argon2idParameters p, Uint8List salt, Uint8List hash) =>
      '\$argon2id\$v=$_version\$m=${p.memoryKiB},t=${p.iterations},p=${p.parallelism}'
      '\$${_b64(salt)}\$${_b64(hash)}';

  static final _format = RegExp(r'^\$argon2id\$v=19\$m=(\d{1,7}),t=(\d{1,2}),p=(\d{1,2})\$([A-Za-z0-9+/]+)\$([A-Za-z0-9+/]+)$');

  static ({Argon2idParameters parameters, Uint8List salt, Uint8List hash})? _decode(String encoded) {
    final match = _format.firstMatch(encoded);
    if (match == null) return null;
    final parameters = Argon2idParameters(
      memoryKiB: int.parse(match.group(1)!),
      iterations: int.parse(match.group(2)!),
      parallelism: int.parse(match.group(3)!),
    );
    if (!parameters.isWithinBounds) return null;
    try {
      final salt = _unb64(match.group(4)!);
      final hash = _unb64(match.group(5)!);
      if (salt.length < 8 || hash.length < 16 || hash.length > 64) return null;
      return (parameters: parameters, salt: salt, hash: hash);
    } on FormatException {
      return null;
    }
  }

  /// Standard base64 without padding, as the Argon2 encoding uses.
  static String _b64(List<int> bytes) => base64.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String text) => base64.decode(text.padRight((text.length + 3) ~/ 4 * 4, '='));

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
