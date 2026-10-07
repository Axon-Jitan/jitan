import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';

/// Every translation key used by this app (and the shared common keys) must
/// have built-in English text, so English always renders completely offline.
void main() {
  test('every key in AdminTextKeys and CommonTextKeys has built-in English', () {
    final sources = [
      File('lib/src/l10n/admin_text_keys.dart'),
      File('../../packages/jitan_core/lib/src/i18n/common_text_keys.dart'),
    ];
    final keyPattern = RegExp(r"static const \w+ = '([^']+)';");

    final keys = {
      for (final file in sources)
        for (final match in keyPattern.allMatches(file.readAsStringSync())) match.group(1)!,
    };
    expect(keys, isNotEmpty, reason: 'key extraction found nothing; pattern out of date?');

    final missing = [
      for (final key in keys)
        if (!builtInEnglish.containsKey(key) &&
            !(builtInEnglish.containsKey('$key.one') && builtInEnglish.containsKey('$key.other')))
          key,
    ];
    expect(missing, isEmpty, reason: 'Add these keys to builtInEnglish (packages/jitan_core).');
  });

  test('screens never pass a literal to context.t (keys come from the key classes)', () {
    final literalLookup = RegExp(r"""\.t\(\s*['"]""");
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && literalLookup.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(offenders, isEmpty);
  });
}
