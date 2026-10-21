import 'dart:convert';

/// Reads the cells of a CSV file (RFC 4180: quoted fields may hold the
/// separator, quotes as `""` and line breaks).
///
/// The separator is the one the first line uses most outside quotes: a
/// comma, a semicolon (Excel's CSV where the decimal sign is a comma, e.g.
/// in Belgium) or a tab. UTF-8, with or without a byte-order mark; text that
/// is not valid UTF-8 is read as Latin-1 (Excel's older CSV export).
abstract final class CsvReader {
  static List<List<String>> read(List<int> bytes) => parse(_decode(bytes));

  static List<List<String>> parse(String text) {
    final separator = _separator(text);
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var i = 0;

    void endCell() {
      row.add(cell.toString());
      cell.clear();
    }

    void endRow() {
      endCell();
      rows.add(row);
      row = <String>[];
    }

    while (i < text.length) {
      final char = text[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(char);
        }
      } else if (char == '"' && cell.isEmpty) {
        quoted = true;
      } else if (char == separator) {
        endCell();
      } else if (char == '\r' || char == '\n') {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        endRow();
      } else {
        cell.write(char);
      }
      i++;
    }
    if (cell.isNotEmpty || row.isNotEmpty) endRow();
    return rows;
  }

  static String _decode(List<int> bytes) {
    var start = 0;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) start = 3;
    final body = bytes.sublist(start);
    try {
      return utf8.decode(body);
    } on FormatException {
      return latin1.decode(body);
    }
  }

  static String _separator(String text) {
    final counts = {',': 0, ';': 0, '\t': 0};
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') quoted = !quoted;
      if (quoted) continue;
      if (char == '\n' || char == '\r') break;
      if (counts.containsKey(char)) counts[char] = counts[char]! + 1;
    }
    final best = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value == 0 ? ',' : best.key;
  }
}
