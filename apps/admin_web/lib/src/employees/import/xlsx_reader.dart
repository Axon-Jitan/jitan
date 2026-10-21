import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';

/// Reads (and, for the template, writes) Excel workbooks.
///
/// Reading is done here directly from the .xlsx parts (a zip of XML files),
/// so files from Excel, Google Sheets, LibreOffice and other tools all read
/// the same way: sheet links that are relative or absolute, shared or
/// inline text, numbers and true/false.
abstract final class XlsxReader {
  static const _relationshipsNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// The cells of the first sheet as text, one list per sheet row (an empty
  /// row is an empty list), so list index + 1 is the row number Excel shows.
  /// Throws [FormatException] when [bytes] are not a readable workbook.
  static List<List<String>> read(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      String? part(String name) {
        final file = archive.findFile(name);
        return file == null ? null : utf8.decode(file.content as List<int>, allowMalformed: true);
      }

      final workbook = XmlDocument.parse(part('xl/workbook.xml') ?? (throw const FormatException('No workbook.')));
      final firstSheet = workbook.findAllElements('sheet').firstOrNull;
      if (firstSheet == null) return const [];
      final relationId = firstSheet.getAttribute('id', namespace: _relationshipsNs) ?? firstSheet.getAttribute('r:id');
      final relations = XmlDocument.parse(part('xl/_rels/workbook.xml.rels') ?? (throw const FormatException('No relations.')));
      final target = relations
          .findAllElements('Relationship')
          .firstWhere((r) => r.getAttribute('Id') == relationId, orElse: () => throw const FormatException('No sheet.'))
          .getAttribute('Target')!;
      // "/xl/worksheets/sheet1.xml" (absolute) or "worksheets/sheet1.xml".
      final sheetPath = target.startsWith('/') ? target.substring(1) : 'xl/$target';
      final sheet = XmlDocument.parse(part(sheetPath) ?? (throw const FormatException('Sheet part missing.')));

      final shared = switch (part('xl/sharedStrings.xml')) {
        null => const <String>[],
        final xml => [for (final item in XmlDocument.parse(xml).findAllElements('si')) _text(item)],
      };

      final rows = <List<String>>[];
      for (final row in sheet.findAllElements('row')) {
        final index = (int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1) - 1;
        while (rows.length <= index) {
          rows.add(<String>[]);
        }
        final cells = rows[index];
        for (final cell in row.findElements('c')) {
          final column = _columnIndex(cell.getAttribute('r')) ?? cells.length;
          while (cells.length <= column) {
            cells.add('');
          }
          cells[column] = _value(cell, shared);
        }
      }
      return rows;
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      throw FormatException('Not a readable .xlsx workbook: $e');
    }
  }

  /// A workbook with one sheet whose first row holds [titles].
  static List<int> workbookWithHeader(List<String> titles) {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow([for (final title in titles) TextCellValue(title)]);
    return workbook.encode() ?? (throw StateError('The template workbook could not be written.'));
  }

  static String _value(XmlElement cell, List<String> shared) {
    final raw = cell.getElement('v')?.innerText ?? '';
    return switch (cell.getAttribute('t')) {
      's' => switch (int.tryParse(raw)) {
        final i? when i >= 0 && i < shared.length => shared[i],
        _ => '',
      },
      'inlineStr' => _text(cell.getElement('is') ?? cell),
      'b' => raw == '1' ? 'true' : 'false',
      'str' || 'e' => raw,
      _ => _number(raw),
    };
  }

  /// A whole number (e.g. a code typed as a number) reads without ".0".
  static String _number(String raw) {
    final value = double.tryParse(raw);
    if (value == null) return raw;
    return value == value.truncateToDouble() && value.abs() < 1e15 ? '${value.toInt()}' : raw;
  }

  /// The text of a string item: every `<t>`, also inside rich-text runs,
  /// but not phonetic hints (`<rPh>`).
  static String _text(XmlElement item) => [
        for (final t in item.findAllElements('t'))
          if (t.parentElement?.name.local != 'rPh') t.innerText,
      ].join();

  /// "C7" → 2.
  static int? _columnIndex(String? reference) {
    final letters = RegExp('^[A-Z]+').stringMatch(reference ?? '');
    if (letters == null) return null;
    var index = 0;
    for (final unit in letters.codeUnits) {
      index = index * 26 + (unit - 64);
    }
    return index - 1;
  }
}
