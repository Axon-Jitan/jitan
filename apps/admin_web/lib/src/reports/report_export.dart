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
    _hours(e.travelMinutes),
    e.daysToReview,
    e.trips,
    double.parse((e.distanceMetres / 1000).toStringAsFixed(1)),
    e.tripsWithoutDistance,
  ];

  /// One row per project (D24): for invoicing, nothing is stored.
  static List<Object> projectRow(ProjectReportProject p) => [
    p.project.sapNumber,
    p.project.name,
    p.project.placeName ?? '',
    p.employees.length,
    _hours(p.workedMinutes),
    _hours(p.travelMinutes),
    p.trips,
    double.parse((p.distanceMetres / 1000).toStringAsFixed(1)),
    p.tripsWithoutDistance,
  ];

  static List<int> excel(List<String> titles, List<HoursReportEmployee> employees) =>
      excelOf(titles, [for (final e in employees) _row(e)]);

  static List<int> csv(List<String> titles, List<HoursReportEmployee> employees) =>
      csvOf(titles, [for (final e in employees) _row(e)]);

  static List<int> excelOf(List<String> titles, List<List<Object>> rows) {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow([for (final title in titles) TextCellValue(title)]);
    for (final row in rows) {
      sheet.appendRow([
        for (final value in row)
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
  static List<int> csvOf(List<String> titles, List<List<Object>> rows) {
    final lines = [
      titles.map(_cell).join(';'),
      for (final row in rows) row.map(_cell).join(';'),
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

  /// `jitan-projects-2026-10.xlsx`.
  static String projectFileName(String month, String extension) => 'jitan-projects-$month.$extension';
}
