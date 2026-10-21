import 'package:excel/excel.dart';

/// Reads (and, for the template, writes) Excel workbooks.
///
/// Reads the cells of the first sheet of an Excel workbook (.xlsx) as text,
/// one list per sheet row (an empty row is an empty list), so list index + 1
/// is the row number Excel shows.
abstract final class XlsxReader {
  /// Throws [FormatException] when [bytes] are not a readable workbook.
  static List<List<String>> read(List<int> bytes) {
    final Excel workbook;
    try {
      workbook = Excel.decodeBytes(bytes);
    } on Object catch (e) {
      throw FormatException('Not a readable .xlsx workbook: $e');
    }
    final sheetName = workbook.getDefaultSheet() ?? workbook.tables.keys.firstOrNull;
    final sheet = sheetName == null ? null : workbook.tables[sheetName];
    if (sheet == null) return const [];
    return [
      for (final row in sheet.rows) [for (final cell in row) _text(cell?.value)],
    ];
  }

  /// A workbook with one sheet whose first row holds [titles].
  static List<int> workbookWithHeader(List<String> titles) {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow([for (final title in titles) TextCellValue(title)]);
    return workbook.encode() ?? (throw StateError('The template workbook could not be written.'));
  }

  static String _text(CellValue? value) => switch (value) {
    null => '',
    TextCellValue() => value.value.toString(),
    IntCellValue(:final value) => '$value',
    // A whole number typed in a cell (e.g. a code) reads without ".0".
    DoubleCellValue(:final value) => value == value.truncateToDouble() && value.abs() < 1e15 ? '${value.toInt()}' : '$value',
    BoolCellValue(:final value) => '$value',
    _ => value.toString(),
  };
}
