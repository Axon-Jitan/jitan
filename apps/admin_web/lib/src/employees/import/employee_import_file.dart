import 'package:jitan_models/jitan_models.dart';

import 'csv_reader.dart';
import 'xlsx_reader.dart';

/// The columns an import file can have ("Columns in the file", Figma
/// `1419:2`), in template order.
enum ImportColumn {
  firstName(required: true),
  lastName(required: true),
  code(required: true),
  phone(required: false),
  email(required: false),
  groups(required: false);

  const ImportColumn({required this.required});

  final bool required;
}

/// Why a file can't be used ("This file can't be used", Figma `1419:101`).
enum ImportFileProblemKind { notExcelOrCsv, unreadable, missingColumn, noEmployees, tooManyEmployees }

class ImportFileProblem implements Exception {
  const ImportFileProblem(this.kind, {this.column, this.count});

  final ImportFileProblemKind kind;

  /// The missing column, for [ImportFileProblemKind.missingColumn].
  final ImportColumn? column;

  /// The employees in the file, for [ImportFileProblemKind.tooManyEmployees].
  final int? count;

  @override
  String toString() => 'ImportFileProblem($kind, $column, $count)';
}

/// A file read for import: its name and size (the file chip) and its rows.
class ImportFile {
  const ImportFile({required this.name, required this.sizeBytes, required this.rows});

  final String name;
  final int sizeBytes;
  final List<EmployeeImportRow> rows;
}

/// Reads an .xlsx or .csv file into [EmployeeImportRow]s. Only reading
/// happens here; whether a row can be imported is the server's decision.
///
/// The first non-empty row holds the column names, matched to
/// [ImportColumn]s by [columnNames] (each column's accepted names; case and
/// extra spaces are ignored). Other columns are ignored. Empty rows are
/// skipped. Groups are names separated by `;`.
abstract final class EmployeeImportFileReader {
  /// Allowed extensions, for the file chooser.
  static const extensions = ['xlsx', 'csv'];

  /// Throws [ImportFileProblem] when the file can't be used.
  static ImportFile read(String name, List<int> bytes, Map<ImportColumn, Set<String>> columnNames) {
    final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final List<List<String>> cells;
    try {
      cells = switch (extension) {
        'xlsx' => XlsxReader.read(bytes),
        'csv' => CsvReader.read(bytes),
        _ => throw const ImportFileProblem(ImportFileProblemKind.notExcelOrCsv),
      };
    } on FormatException {
      throw const ImportFileProblem(ImportFileProblemKind.unreadable);
    }
    return ImportFile(name: name, sizeBytes: bytes.length, rows: rowsOf(cells, columnNames));
  }

  /// The employees in [cells] (one list per file row).
  static List<EmployeeImportRow> rowsOf(List<List<String>> cells, Map<ImportColumn, Set<String>> columnNames) {
    bool blank(List<String> row) => row.every((cell) => cell.trim().isEmpty);
    final headerIndex = cells.indexWhere((row) => !blank(row));
    if (headerIndex < 0) throw const ImportFileProblem(ImportFileProblemKind.noEmployees);

    final wanted = {
      for (final MapEntry(key: column, value: names) in columnNames.entries)
        for (final name in names) _normalized(name): column,
    };
    final positions = <ImportColumn, int>{};
    for (final (index, title) in cells[headerIndex].indexed) {
      final column = wanted[_normalized(title)];
      if (column != null) positions.putIfAbsent(column, () => index);
    }
    for (final column in ImportColumn.values) {
      if (column.required && !positions.containsKey(column)) {
        throw ImportFileProblem(ImportFileProblemKind.missingColumn, column: column);
      }
    }

    String? value(List<String> row, ImportColumn column) {
      final index = positions[column];
      if (index == null || index >= row.length) return null;
      final text = row[index].trim();
      return text.isEmpty ? null : text;
    }

    final rows = [
      for (var i = headerIndex + 1; i < cells.length; i++)
        if (!blank(cells[i]))
          EmployeeImportRow(
            row: i + 1,
            firstName: value(cells[i], ImportColumn.firstName) ?? '',
            lastName: value(cells[i], ImportColumn.lastName) ?? '',
            code: value(cells[i], ImportColumn.code) ?? '',
            phone: value(cells[i], ImportColumn.phone),
            email: value(cells[i], ImportColumn.email),
            groups: [
              for (final group in (value(cells[i], ImportColumn.groups) ?? '').split(';'))
                if (group.trim().isNotEmpty) group.trim(),
            ],
          ),
    ];
    if (rows.isEmpty) throw const ImportFileProblem(ImportFileProblemKind.noEmployees);
    if (rows.length > EmployeeImportRequest.maxRows) {
      throw ImportFileProblem(ImportFileProblemKind.tooManyEmployees, count: rows.length);
    }
    return rows;
  }

  /// The template ("Download template"): a workbook whose first row holds
  /// [titles]. An .xlsx, so Excel opens it in columns whatever the
  /// computer's list separator.
  static List<int> template(List<String> titles) => XlsxReader.workbookWithHeader(titles);

  static String _normalized(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
