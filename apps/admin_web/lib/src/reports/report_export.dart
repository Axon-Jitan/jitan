import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:jitan_models/jitan_models.dart';

/// The report as a file for payroll: one row per employee, hours as decimal
/// numbers. "The file payroll keeps is the record" (D24): nothing is stored.
abstract final class ReportExport {
  static const excelType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const csvType = 'text/csv';

  static double _hours(int minutes) => double.parse((minutes / 60).toStringAsFixed(2));

  static List<Object> _row(HoursReportEmployee e) => [
    e.code,
    e.firstName ?? '',
    e.lastName ?? '',
    _hours(e.plannedMinutes),
    _hours(e.registeredMinutes),
    _hours(e.differenceMinutes),
    e.daysToReview,
  ];

  static List<int> excel(List<String> titles, List<HoursReportEmployee> employees) {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow([for (final title in titles) TextCellValue(title)]);
    for (final employee in employees) {
      sheet.appendRow([
        for (final value in _row(employee))
          switch (value) {
            final int v => IntCellValue(v),
            final double v => DoubleCellValue(v),
            _ => TextCellValue('$value'),
          },
      ]);
    }
    return workbook.encode() ?? (throw StateError('The report workbook could not be written.'));
  }

  /// Semicolons, as Excel expects in Belgium. A byte order mark keeps é and ü.
  static List<int> csv(List<String> titles, List<HoursReportEmployee> employees) {
    final lines = [
      titles.map(_cell).join(';'),
      for (final employee in employees) _row(employee).map(_cell).join(';'),
    ];
    return [0xEF, 0xBB, 0xBF, ...utf8.encode('${lines.join('\r\n')}\r\n')];
  }

  /// A spreadsheet runs a text starting with `=`, `+`, `-` or `@` as a
  /// formula, and a name is typed by people: such a text gets a leading `'`.
  static String _cell(Object value) {
    if (value is num) return '$value';
    var text = '$value';
    if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) text = "'$text";
    return text.contains(RegExp('[;"\r\n]')) ? '"${text.replaceAll('"', '""')}"' : text;
  }

  /// `jitan-hours-2026-10.xlsx`.
  static String fileName(String month, String extension) => 'jitan-hours-$month.$extension';
}
