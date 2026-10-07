import 'package:jitan_api/src/auth/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  const hasher = PasswordHasher(cost: 4);

  test('produces salted bcrypt \$2b\$ hashes that verify', () async {
    final a = await hasher.hash('correct horse');
    final b = await hasher.hash('correct horse');

    expect(a, startsWith(r'$2b$04$'));
    expect(a, isNot(b), reason: 'random salt per hash');
    expect(await hasher.verify('correct horse', a), isTrue);
    expect(await hasher.verify('correct horse', b), isTrue);
    expect(await hasher.verify('wrong horse', a), isFalse);
  });

  test('a malformed stored hash is a mismatch, not a crash', () async {
    expect(await hasher.verify('anything', 'not-a-hash'), isFalse);
    expect(await hasher.verify('anything', ''), isFalse);
  });

  test('production cost is 12 and never below the minimum', () {
    expect(PasswordHasher.defaultCost, 12);
    expect(PasswordHasher.defaultCost, greaterThanOrEqualTo(PasswordHasher.minimumCost));
    expect(const PasswordHasher().cost, PasswordHasher.defaultCost);
  });
}
