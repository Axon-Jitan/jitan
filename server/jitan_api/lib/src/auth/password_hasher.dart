import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

/// Hashes and verifies passwords for `tblUser.userPassword`.
///
/// bcrypt, `$2b$` format, cost [defaultCost] (about 0.3 s per hash in the
/// compiled server). The format is self-describing, so if IT requires another
/// algorithm (CLARIFY-01), existing hashes can be recognised and migrated on
/// the user's next sign-in.
///
/// Work runs on a separate isolate so hashing never blocks other requests.
/// bcrypt reads at most 72 bytes; [PasswordPolicy] rejects longer passwords
/// instead of letting them be silently truncated.
class PasswordHasher {
  const PasswordHasher({this.cost = defaultCost});

  static const defaultCost = 12;

  /// Lowest cost allowed outside tests.
  static const minimumCost = 10;

  final int cost;

  Future<String> hash(String password) {
    final rounds = cost;
    return Isolate.run(() => BCrypt.hashpw(password, BCrypt.gensalt(prefix: r'$2b', logRounds: rounds)));
  }

  /// Whether [password] matches [storedHash]. A malformed hash is a mismatch,
  /// not an error. The comparison takes the same time wherever the first
  /// difference is.
  Future<bool> verify(String password, String storedHash) => Isolate.run(() {
        try {
          return _constantTimeEquals(BCrypt.hashpw(password, storedHash), storedHash);
        } on Object {
          return false;
        }
      });

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return difference == 0;
  }
}
