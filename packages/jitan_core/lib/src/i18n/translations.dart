import 'package:logging/logging.dart';

final _log = Logger('i18n');

/// Code of the default and fallback language. It is an ordinary
/// `tblLanguage` row; this is only the code the fallback chain looks for.
const fallbackLanguageCode = 'en';

/// Loaded UI texts for one language, with the fallback chain:
///
/// ```text
/// selected language → English → the key itself (logged once)
/// ```
///
/// Every text comes from `tblTranslation` bundles; nothing here is a
/// source of copy.
class Translations {
  Translations({
    required this.languageCode,
    required this._selected,
    required this._fallback,
  });

  /// No texts at all: every lookup shows its key. Used before any bundle
  /// could be loaded (e.g. the API address is missing) and in tests that
  /// assert which key a widget uses.
  Translations.keysOnly() : this(languageCode: fallbackLanguageCode, selected: const {}, fallback: const {});

  /// The language actually being shown.
  final String languageCode;

  final Map<String, String> _selected;
  final Map<String, String> _fallback;
  final _reportedMissing = <String>{};

  /// The text for [key], with `{name}` placeholders replaced from [args].
  String t(String key, {Map<String, Object> args = const {}}) {
    final text = _selected[key] ?? _fallback[key] ?? _missing(key);
    return args.isEmpty ? text : _substitute(text, args);
  }

  /// Picks `<key>.one` for a count of 1 and `<key>.other` otherwise, with
  /// `{n}` replaced by [count].
  ///
  /// The one/other split fits English and Dutch. Languages with other plural
  /// rules (e.g. French treats 0 as singular) need richer keys when they are
  /// added.
  String plural(String key, int count) =>
      t(count == 1 ? '$key.one' : '$key.other', args: {'n': count});

  bool has(String key) => _selected.containsKey(key) || _fallback.containsKey(key);

  String _missing(String key) {
    if (_reportedMissing.add(key)) {
      _log.warning('Missing translation "$key" in "$languageCode" and in fallback "$fallbackLanguageCode".');
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
