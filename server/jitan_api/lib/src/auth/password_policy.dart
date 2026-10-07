import 'dart:convert';

import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';

/// Rules a new password must meet. The one place they are defined.
///
/// Development defaults, pending PRODUCT-CLARIFY-PASSWORD-POLICY:
/// - at least [minLength] characters, not only whitespace
/// - at most [maxBytes] UTF-8 bytes: bcrypt ignores everything after 72
///   bytes, so a longer password is refused instead of silently shortened
abstract final class PasswordPolicy {
  static const minLength = 8;
  static const maxBytes = 72;

  /// Throws 400 `validation_failed` (field `password`) when [password] breaks
  /// a rule. The password is used exactly as given: never trimmed.
  static void check(String password) {
    if (password.trim().isEmpty || password.runes.length < minLength) {
      throw const ApiException.validation(
        OnboardingCompleteRequest.fieldPassword,
        'The password must be at least $minLength characters.',
      );
    }
    if (utf8.encode(password).length > maxBytes) {
      throw const ApiException.validation(
        OnboardingCompleteRequest.fieldPassword,
        'The password is too long.',
      );
    }
  }
}
