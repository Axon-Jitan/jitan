import 'package:logging/logging.dart';

import 'built_in_english.dart';

final _log = Logger('i18n');

/// Code of English, the built-in default language. English is never loaded
/// from the database; see [builtInEnglish].
const englishLanguageCode = 'en';

/// UI texts for one language, resolved per key:
///
/// ```text
/// selected language (database bundle, non-English only)
///   ↓ missing
/// built-in English
///   ↓ missing
/// the key itself (logged once)
/// ```
class Translations {
  /// [selected] is the database bundle of [languageCode]; empty for English.
  /// [fallback] is the built-in English bundle; replaceable only in tests.
  Translations({required this.languageCode, Map<String, String> selected = const {}, this._fallback = builtInEnglish})
    : _selected = languageCode == englishLanguageCode ? const {} : selected;

  /// English only. Always available, with no network.
  Translations.english() : this(languageCode: englishLanguageCode);

  /// The language whose database bundle is applied (`en` = built-in only).
  final String languageCode;

  final Map<String, String> _selected;
  final Map<String, String> _fallback;
  final _reportedMissing = <String>{};

  /// The text for [key], with `{name}` placeholders replaced from [args].
  String t(String key, {Map<String, Object> args = const {}}) {
    final text = _selected[key] ?? _fallback[key] ?? _missing(key);
    return args.isEmpty ? text : _substitute(text, args);
  }

  /// The text for [key] when this language or English has one; `null`
  /// otherwise (not logged). For optional texts built from data, e.g. a
  /// language's name for each `tblLanguage` row.
  String? tOrNull(String key) => _selected[key] ?? _fallback[key];

  /// `<key>.one` for a count of 1, `<key>.other` otherwise, with `{n}`
  /// replaced by [count].
  ///
  /// The one/other split fits English and Dutch. Languages with other plural
  /// rules (e.g. French treats 0 as singular) need richer keys when added.
  String plural(String key, int count) => t(count == 1 ? '$key.one' : '$key.other', args: {'n': count});

  String _missing(String key) {
    if (_reportedMissing.add(key)) {
      _log.warning('Missing translation "$key": not in "$languageCode" nor in built-in English.');
    }
    return key;
  }

  static String _substitute(String text, Map<String, Object> args) {
    var result = text;
    for (final MapEntry(:key, :value) in args.entries) {
      result = result.replaceAll('{$key}', '$value');
    }
    return result;
  }
}
