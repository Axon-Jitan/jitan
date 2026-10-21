import 'package:phone_numbers_parser/phone_numbers_parser.dart' as parser;

/// Why a phone number is refused.
enum PhoneNumberProblem {
  /// Letters or other signs: only digits, spaces, `+ ( ) - .` are allowed.
  notANumber,

  /// No `+` and country code (product owner, 2026-10-21: always required,
  /// no country is assumed).
  missingCountryCode,

  /// Not a possible number for its country (too short, too long, …).
  invalid,
}

/// The phone number rule of Jitan, the same in every client and the server:
/// an international number with `+` and its country code, stored in one
/// readable form, e.g. `+32 470 12 34 56` (`tblUser.cellphoneNumber`).
abstract final class PhoneNumbers {
  static final _allowedSigns = RegExp(r'^[0-9 +().\-]*$');

  /// [input] in Jitan's form, or the [PhoneNumberProblem] that refuses it.
  /// A blank [input] is not checked here (the phone is optional).
  static ({String? formatted, PhoneNumberProblem? problem}) check(String input) {
    final text = input.trim();
    if (!_allowedSigns.hasMatch(text) || text.indexOf('+') > 0 || '+'.allMatches(text).length > 1) {
      return (formatted: null, problem: PhoneNumberProblem.notANumber);
    }
    if (!text.startsWith('+')) return (formatted: null, problem: PhoneNumberProblem.missingCountryCode);
    final parser.PhoneNumber number;
    try {
      number = parser.PhoneNumber.parse(text);
    } on parser.PhoneNumberException {
      return (formatted: null, problem: PhoneNumberProblem.invalid);
    }
    if (!number.isValid()) return (formatted: null, problem: PhoneNumberProblem.invalid);
    return (formatted: _format(number), problem: null);
  }

  /// [input] arranged while it is typed: only a leading `+` and digits are
  /// kept, grouped the way the number's country writes them once the
  /// country code is known (`+32470123456` → `+32 470 12 34 56`).
  static String asTyped(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final plus = input.trimLeft().startsWith('+');
    if (!plus) return digits;
    if (digits.isEmpty) return '+';
    try {
      final number = parser.PhoneNumber.parse('+$digits');
      if (number.nsn.isEmpty) return '+$digits';
      return _format(number);
    } on parser.PhoneNumberException {
      return '+$digits';
    }
  }

  static String _format(parser.PhoneNumber number) =>
      '+${number.countryCode} ${number.formatNsn(format: parser.NsnFormat.international)}'.trim();
}
