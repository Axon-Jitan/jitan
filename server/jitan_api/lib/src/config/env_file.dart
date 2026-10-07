/// Parses the contents of a development `.env` file.
///
/// Supported: `KEY=value`, optional `export ` prefix, blank lines, `#`
/// comment lines, and values wrapped in matching single or double quotes.
/// No variable expansion. A line without `=` is an error, so typos fail
/// loudly instead of silently dropping a setting.
Map<String, String> parseEnvFile(Iterable<String> lines) {
  final values = <String, String>{};
  var lineNumber = 0;
  for (final rawLine in lines) {
    lineNumber++;
    var line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring('export '.length).trim();

    final separator = line.indexOf('=');
    if (separator <= 0) {
      throw FormatException('.env line $lineNumber is not KEY=value: "$rawLine"');
    }
    final key = line.substring(0, separator).trim();
    values[key] = _unquote(line.substring(separator + 1).trim());
  }
  return values;
}

String _unquote(String value) {
  if (value.length >= 2) {
    final first = value[0];
    if ((first == '"' || first == "'") && value.endsWith(first)) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}
