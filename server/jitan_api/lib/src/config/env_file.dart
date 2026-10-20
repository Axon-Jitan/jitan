/// Parses a configuration file: IT's `/etc/jitan/app.env`, or a development
/// `.env` (docs/DEPLOYMENT_CONFIGURATION.md).
///
/// Supported: `KEY=value`, an optional `export ` prefix, blank lines, `#`
/// comment lines, values in matching single or double quotes, and a UTF-8
/// byte-order mark. Nothing is expanded or executed. A malformed line, an
/// invalid key, an unclosed quote or a key given twice is a [FormatException],
/// so typos fail loudly instead of silently dropping a setting.
///
/// Error messages name the line number only, never its content: the file
/// holds secrets such as `DB_PASS`.
Map<String, String> parseEnvFile(Iterable<String> lines) {
  final values = <String, String>{};
  var lineNumber = 0;
  for (final rawLine in lines) {
    lineNumber++;
    var line = rawLine.trim();
    if (lineNumber == 1 && line.startsWith('﻿')) line = line.substring(1).trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring('export '.length).trim();

    final separator = line.indexOf('=');
    if (separator <= 0) throw FormatException('Configuration line $lineNumber is not KEY=value.');
    final key = line.substring(0, separator).trim();
    if (!_key.hasMatch(key)) throw FormatException('Configuration line $lineNumber has an invalid key.');
    if (values.containsKey(key)) throw FormatException('Configuration line $lineNumber repeats a key.');
    values[key] = _unquote(line.substring(separator + 1).trim(), lineNumber);
  }
  return values;
}

final _key = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

String _unquote(String value, int lineNumber) {
  if (value.isEmpty) return value;
  final first = value[0];
  if (first != '"' && first != "'") return value;
  if (value.length < 2 || !value.endsWith(first)) {
    throw FormatException('Configuration line $lineNumber has an unclosed quote.');
  }
  return value.substring(1, value.length - 1);
}
