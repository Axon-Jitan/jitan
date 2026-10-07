import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';

/// Rules a new password must meet. The one place they are defined (V1,
/// agreed 2026-10-07).
///
/// - at least [minLength] characters; [recommendedLength]+ is recommended
///   (shown by the apps, not enforced)
/// - letters, numbers and symbols all allowed; no composition rules
/// - not only whitespace
/// - at most [maxLength] characters: no algorithm limit applies (Argon2id
///   takes any length), this only bounds the work one request can cause
/// - used exactly as typed, never trimmed
abstract final class PasswordPolicy {
  static const minLength = 8;
  static const recommendedLength = 12;
  static const maxLength = 256;

  /// Throws 400 `validation_failed` on [field] when [password] breaks a rule.
  static void check(String password, {String field = OnboardingCompleteRequest.fieldPassword}) {
    final length = password.runes.length;
    if (password.trim().isEmpty || length < minLength) {
      throw ApiException.validation(field, 'The password must be at least $minLength characters.');
    }
    if (length > maxLength) {
      throw ApiException.validation(field, 'The password must be at most $maxLength characters.');
    }
  }
}
