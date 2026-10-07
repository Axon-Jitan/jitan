/// Why a new password was not accepted.
enum PasswordProblem { tooShort, tooLong, mismatch, rejected }

/// The password rules the apps check before sending (the server enforces
/// the same, `PasswordPolicy`): 8+ characters (12+ recommended, only shown
/// as a hint), at most 256, not only spaces, typed twice identically.
abstract final class PasswordRules {
  static const minLength = 8;
  static const maxLength = 256;

  /// The first problem with [password] and its [confirmation], or `null`.
  static PasswordProblem? check(String password, String confirmation) {
    final length = password.runes.length;
    if (password.trim().isEmpty || length < minLength) return PasswordProblem.tooShort;
    if (length > maxLength) return PasswordProblem.tooLong;
    if (password != confirmation) return PasswordProblem.mismatch;
    return null;
  }
}
