import 'dart:convert';

import 'package:admin_web/src/employees/import/csv_reader.dart';
import 'package:admin_web/src/employees/import/employee_import_file.dart';
import 'package:admin_web/src/employees/import/xlsx_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';

const _names = {
  ImportColumn.firstName: {'First name'},
  ImportColumn.lastName: {'Last name'},
  ImportColumn.code: {'Employee code'},
  ImportColumn.phone: {'Phone'},
  ImportColumn.email: {'Email'},
  ImportColumn.groups: {'Groups', 'Groepen'},
};

ImportFile _csv(String text, {String name = 'people.csv'}) =>
    EmployeeImportFileReader.read(name, utf8.encode(text), _names);

Matcher _problem(ImportFileProblemKind kind) => throwsA(isA<ImportFileProblem>().having((p) => p.kind, 'kind', kind));

void main() {
  group('CsvReader', () {
    test('comma, semicolon or tab, whichever the first line uses', () {
      expect(CsvReader.parse('a,b\n1,2'), [['a', 'b'], ['1', '2']]);
      expect(CsvReader.parse('a;b\r\n1;2,5\r\n'), [['a', 'b'], ['1', '2,5']]);
      expect(CsvReader.parse('a\tb\n1\t2'), [['a', 'b'], ['1', '2']]);
    });

    test('quoted fields hold separators, quotes and line breaks', () {
      expect(CsvReader.parse('a;b\n"x;y";"say ""hi"""\n"two\nlines";z'), [
        ['a', 'b'],
        ['x;y', 'say "hi"'],
        ['two\nlines', 'z'],
      ]);
    });

    test('UTF-8 with a byte-order mark, and Latin-1 from older Excel', () {
      expect(CsvReader.read([0xEF, 0xBB, 0xBF, ...utf8.encode('Chloé')]), [['Chloé']]);
      expect(CsvReader.read(latin1.encode('Chloé')), [['Chloé']]);
    });
  });

  group('EmployeeImportFileReader', () {
    test('matches columns by name in any order, case and spacing; keeps file row numbers', () {
      final file = _csv(
        '\n'
        'employee  CODE,Last name,Extra,FIRST NAME,Groepen,Phone\n'
        'APE,Peeters,x, Anna ,Blue collar; Drivers ;,+32 470\n'
        ',,,,,\n'
        'BJA,Janssens,,Bram,,\n',
      );

      expect(file.name, 'people.csv');
      expect([for (final r in file.rows) (r.row, r.firstName, r.lastName, r.code, r.phone, r.email, r.groups.join('|'))], [
        (3, 'Anna', 'Peeters', 'APE', '+32 470', null, 'Blue collar|Drivers'),
        (5, 'Bram', 'Janssens', 'BJA', null, null, ''),
      ]);
    });

    test('a missing value is empty, for the server to report', () {
      final row = _csv('First name,Last name,Employee code\nDries,,DRI\n').rows.single;

      expect((row.firstName, row.lastName, row.code), ('Dries', '', 'DRI'));
    });

    test('a missing required column, no employees, or too many make the file unusable', () {
      expect(
        () => _csv('First name,Employee code\nA,B\n'),
        throwsA(isA<ImportFileProblem>()
            .having((p) => p.kind, 'kind', ImportFileProblemKind.missingColumn)
            .having((p) => p.column, 'column', ImportColumn.lastName)),
      );
      expect(() => _csv('First name,Last name,Employee code\n\n'), _problem(ImportFileProblemKind.noEmployees));
      expect(() => _csv(''), _problem(ImportFileProblemKind.noEmployees));
      final many = StringBuffer('First name,Last name,Employee code\n');
      for (var i = 0; i <= EmployeeImportRequest.maxRows; i++) {
        many.writeln('A,B,C$i');
      }
      expect(
        () => _csv('$many'),
        throwsA(isA<ImportFileProblem>()
            .having((p) => p.kind, 'kind', ImportFileProblemKind.tooManyEmployees)
            .having((p) => p.count, 'count', EmployeeImportRequest.maxRows + 1)),
      );
    });

    test('only .xlsx and .csv; a broken workbook is unreadable', () {
      expect(() => _csv('x', name: 'people.xls'), _problem(ImportFileProblemKind.notExcelOrCsv));
      expect(() => _csv('x', name: 'people'), _problem(ImportFileProblemKind.notExcelOrCsv));
      expect(() => EmployeeImportFileReader.read('people.XLSX', [1, 2, 3], _names), _problem(ImportFileProblemKind.unreadable));
    });

    test('the template is a workbook whose first row holds the column names, and reads back', () {
      final template = EmployeeImportFileReader.template(['First name', 'Last name', 'Employee code']);

      expect(XlsxReader.read(template).first, ['First name', 'Last name', 'Employee code']);
      expect(
        () => EmployeeImportFileReader.read('template.xlsx', template, _names),
        _problem(ImportFileProblemKind.noEmployees),
      );
    });
  });
}
