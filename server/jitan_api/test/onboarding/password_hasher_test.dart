import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:test/test.dart';

/// Cheap parameters keep the suite fast; the encoding and algorithm are the
/// same as in production.
const _fast = PasswordHasher(parameters: Argon2idParameters(memoryKiB: 8192, iterations: 1));

void main() {
  group('Argon2id', () {
    test('correct password verifies; wrong password is rejected', () async {
      final hash = await _fast.hash('correct horse');

      expect(await _fast.verify('correct horse', hash), isTrue);
      expect(await _fast.verify('wrong horse', hash), isFalse);
      expect(await _fast.verify('correct horse ', hash), isFalse, reason: 'exact match, never trimmed');
    });

    test('identical passwords give different hashes (random salt per password)', () async {
      final a = await _fast.hash('same password');
      final b = await _fast.hash('same password');

      expect(a, isNot(b));
      expect(await _fast.verify('same password', a), isTrue);
      expect(await _fast.verify('same password', b), isTrue);
    });

    test('standard self-describing encoding with the parameters inside', () async {
      final hash = await _fast.hash('x' * 10);

      expect(hash, matches(RegExp(r'^\$argon2id\$v=19\$m=8192,t=1,p=1\$[A-Za-z0-9+/]{22}\$[A-Za-z0-9+/]{43}$')));
      expect(hash, isNot(contains('xxxxxxxxxx')));
    });

    test('verifies a hash produced by libsodium (interoperable format)', () async {
      // libsodium crypto_pwhash_str, opslimit 2, memlimit 19 MiB.
      const libsodiumHash =
          r'$argon2id$v=19$m=19456,t=2,p=1$zErgkdjGsO0Ach9svPT+8Q$lVRMkkxj5BHFhLsdVqkjsewhIzwbq01+cB6r4+yTnOE';
      const hasher = PasswordHasher();

      expect(await hasher.verify('correct horse battery staple', libsodiumHash), isTrue);
      expect(await hasher.verify('correct horse battery stapl', libsodiumHash), isFalse);
    });

    test('no 72-byte limit: every byte of a long password counts', () async {
      final long = 'é' * 100; // 200 UTF-8 bytes
      final hash = await _fast.hash(long);

      expect(await _fast.verify(long, hash), isTrue);
      expect(await _fast.verify('${'é' * 99}e', hash), isFalse);
    });

    test('malformed, foreign or out-of-bounds hashes are mismatches, never errors', () async {
      for (final stored in [
        '',
        'not-a-hash',
        r'$2b$12$abcdefghijklmnopqrstuuJ9Kc2T1t0FfQOqGq0Y8u6qkq0bCq4m', // another system's format (CLARIFY-01)
        r'$argon2i$v=19$m=19456,t=2,p=1$zErgkdjGsO0Ach9svPT+8Q$lVRMkkxj5BHFhLsdVqkjsewhIzwbq01+cB6r4+yTnOE',
        r'$argon2id$v=19$m=9999999,t=2,p=1$zErgkdjGsO0Ach9svPT+8Q$lVRMkkxj5BHFhLsdVqkjsewhIzwbq01+cB6r4+yTnOE',
        r'$argon2id$v=19$m=19456,t=2,p=1$!!!$lVRMkkxj5BHFhLsdVqkjsewhIzwbq01+cB6r4+yTnOE',
      ]) {
        expect(await _fast.verify('anything', stored), isFalse, reason: stored);
      }
    });

    test('needsRehash when the stored parameters differ from the current ones', () async {
      final weak = await _fast.hash('pw');
      const current = PasswordHasher();

      expect(current.needsRehash(weak), isTrue);
      expect(_fast.needsRehash(weak), isFalse);
      expect(current.needsRehash(r'$2b$12$legacy'), isTrue);
    });

    test('production parameters are the OWASP recommendation', () {
      expect(Argon2idParameters.recommended, const Argon2idParameters(memoryKiB: 19456, iterations: 2));
      expect(const PasswordHasher().parameters, Argon2idParameters.recommended);
      expect(Argon2idParameters.recommended.isWithinBounds, isTrue);
    });
  });
}
