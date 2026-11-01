import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';

/// Every key of this app has built-in English, so a tablet always renders
/// completely, also with no connection.
void main() {
  test('every key in TerminalTextKeys has built-in English', () {
    final keyPattern = RegExp(r"static const \w+ = '([^']+)';");
    final keys = {
      for (final match in keyPattern.allMatches(File('lib/src/l10n/terminal_text_keys.dart').readAsStringSync())) match.group(1)!,
    };
    expect(keys, isNotEmpty, reason: 'key extraction found nothing; pattern out of date?');

    final missing = [
      for (final key in keys)
        if (!builtInEnglish.containsKey(key)) key,
    ];
    expect(missing, isEmpty, reason: 'Add these keys to builtInEnglish (packages/jitan_core).');
  });

  test('screens never pass a literal to context.t (keys come from the key class)', () {
    final literalLookup = RegExp(r"""\.t\(\s*['"]""");
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && literalLookup.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(offenders, isEmpty);
  });
}
