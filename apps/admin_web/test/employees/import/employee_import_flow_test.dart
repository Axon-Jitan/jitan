import 'dart:convert';

import 'package:admin_web/src/app/admin_routes.dart';
import 'package:admin_web/src/company_context/current_company.dart';
import 'package:admin_web/src/employees/import/employee_import_screen.dart';
import 'package:admin_web/src/employees/import/platform/import_file_picker.dart';
import 'package:admin_web/src/employees/import/xlsx_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../../support/fake_companies_api.dart';
import '../../support/fake_employees_api.dart';

const _csv = 'First name;Last name;Employee code;Groups;Phone\n'
    'Anna;Peeters;APE;Blue collar;+32 470 12 34 56\n'
    'Dries;;DRI;Blue collar;\n'
    'Elise;Willems;SBW;White collar;\n';

/// Import employees (Figma `1419:2` → `1419:50` → `1419:149` → `1419:259` →
/// `1419:369`): choose a file, see each row's status from the server, import
/// the ready rows, and nothing is reported before the server confirms.
void main() {
  late FakeEmployeesApi api;
  late FakeCompaniesApi companies;
  late List<ChosenImportFile?> nextFiles;
  late List<(String, List<int>, String)> downloads;

  Future<void> pumpPage(WidgetTester tester, {Size size = const Size(1440, 1024)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = FakeEmployeesApi();
    companies = FakeCompaniesApi();
    nextFiles = [];
    downloads = [];
    final current = CurrentCompanyController()..select(company(7, 'Almeco'));
    addTearDown(current.dispose);
    final router = GoRouter(
      initialLocation: AdminRoutes.employeeImport,
      routes: [
        GoRoute(
          path: AdminRoutes.employees,
          builder: (context, state) => const Scaffold(body: Text('[Employees page]')),
          routes: [
            GoRoute(
              path: 'import',
              builder: (context, state) => Scaffold(
                body: EmployeeImportScreen(
                  api: api,
                  companiesApi: companies,
                  chooseFile: () async => nextFiles.removeAt(0),
                  download: (name, bytes, type) => downloads.add((name, bytes, type)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: CurrentCompanyScope(
          controller: current,
          child: MaterialApp.router(theme: JitanTheme.web(), routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    companies.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
    await tester.pump();
    await tester.pump();
  }

  /// "Company" on the Import page: Almeco.
  Future<void> chooseCompany(WidgetTester tester) async {
    tester.widget<JitanSelectField<int>>(find.byType(JitanSelectField<int>)).onChanged!(7);
    await tester.pump();
  }

  Future<void> chooseFile(WidgetTester tester, String name, List<int> bytes, {String button = 'Choose file'}) async {
    nextFiles.add(ChosenImportFile(name: name, bytes: bytes));
    await tester.tap(find.text(button).last);
    await tester.pump();
  }

  testWidgets('Ready: drop area, columns and the company the employees go to', (tester) async {
    await pumpPage(tester);

    expect(find.text('Import employees'), findsOneWidget);
    expect(find.text('Add many employees at once from an Excel or CSV file.'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Select a company'), findsOneWidget, reason: 'the Employees filter never chooses for an import');
    expect(find.text('Choose the company first · .xlsx or .csv · up to 500 employees'), findsOneWidget);
    expect(tester.widget<JitanOutlineButton>(find.widgetWithText(JitanOutlineButton, 'Choose file')).onPressed, isNull);

    await chooseCompany(tester);
    expect(find.text('Drop an Excel or CSV file here'), findsOneWidget);
    expect(find.text('.xlsx or .csv · up to 500 employees'), findsOneWidget);
    expect(find.text('Columns in the file'), findsOneWidget);
    for (final column in ['First name', 'Last name', 'Employee code', 'Phone', 'Email', 'Groups']) {
      expect(find.text(column), findsOneWidget);
    }
    expect(find.text('Required'), findsNWidgets(3));
    expect(find.text('Optional · separate names with ;'), findsOneWidget);
  });

  testWidgets('Download template saves a workbook with the column names', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Download template'));

    final (name, bytes, type) = downloads.single;
    expect(name, 'jitan-employees-template.xlsx');
    expect(type, contains('spreadsheetml'));
    expect(XlsxReader.read(bytes).first, ['First name', 'Last name', 'Employee code', 'Phone', 'Email', 'Groups']);
  });

  testWidgets('choose → reading → preview with problems → import → done', (tester) async {
    await pumpPage(tester);
    await chooseCompany(tester);

    await chooseFile(tester, 'almeco.csv', utf8.encode(_csv));

    expect(find.text('Reading file…'), findsOneWidget);
    final (companyId, request) = api.importChecks.single;
    expect(companyId, 7);
    expect([for (final r in request.rows) (r.row, r.code)], [(2, 'APE'), (3, 'DRI'), (4, 'SBW')]);

    api.checkSucceeds(const [
      EmployeeImportProblem(row: 3, kind: EmployeeImportProblemKind.lastNameMissing),
      EmployeeImportProblem(row: 4, kind: EmployeeImportProblemKind.codeUsed, detail: 'SBW'),
    ]);
    await tester.pump();

    expect(find.text('rows in file'), findsOneWidget);
    expect(find.text('ready to import'), findsOneWidget);
    expect(find.text('with problems'), findsOneWidget);
    expect(find.text('almeco.csv'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Last name is missing'), findsOneWidget);
    expect(find.text('Code SBW is already used'), findsOneWidget);
    expect(find.text('+32 470 12 34 56'), findsOneWidget);
    expect(find.text('Rows with problems are skipped. Fix them in the file and import it again to add them later.'), findsOneWidget);

    await tester.tap(find.text('Import 1 employee'));
    await tester.pump();

    expect(find.text('Importing 1 employee…'), findsOneWidget);
    expect(tester.widget<JitanPrimaryButton>(find.byType(JitanPrimaryButton)).onPressed, isNull);
    expect(api.imports.single.$2.rows, hasLength(3), reason: 'the server checks every row again');
    expect(find.textContaining(RegExp(r'employees? added to')), findsNothing, reason: 'no success before the server confirms');

    api.importSucceeds(const EmployeeImportResult(
      added: 1,
      skipped: [
        EmployeeImportProblem(row: 3, kind: EmployeeImportProblemKind.lastNameMissing),
        EmployeeImportProblem(row: 4, kind: EmployeeImportProblemKind.codeUsed, detail: 'SBW'),
      ],
    ));
    await tester.pump();

    expect(find.text('1 employee added to Almeco'), findsOneWidget);
    expect(
      find.text('2 rows with problems were skipped. Each new employee activates the app with an onboarding QR from Employees.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Back to Employees'));
    await tester.pumpAndSettle();
    expect(find.text('[Employees page]'), findsOneWidget);
  });

  testWidgets('a failed import keeps the preview and says why; nothing was added', (tester) async {
    await pumpPage(tester);
    await chooseCompany(tester);
    await chooseFile(tester, 'almeco.csv', utf8.encode(_csv));
    api.checkSucceeds(const []);
    await tester.pump();

    await tester.tap(find.text('Import 3 employees'));
    await tester.pump();
    api.importFails(const ApiClientException.network('offline'));
    await tester.pump();

    expect(find.text('Import 3 employees'), findsOneWidget);
    expect(find.textContaining(RegExp(r'employees? added to')), findsNothing);
    expect(find.text('Rows with problems are skipped. Fix them in the file and import it again to add them later.'), findsNothing);
  });

  testWidgets("a file that can't be used says why; another file can be chosen", (tester) async {
    await pumpPage(tester);
    await chooseCompany(tester);

    await chooseFile(tester, 'almeco.csv', utf8.encode('First name;Last name\nA;B\n'));

    expect(find.text('This file can’t be used'), findsOneWidget);
    expect(find.text('The column "Employee code" is missing. Use the template, or add the column and try again.'), findsOneWidget);
    expect(api.importChecks, isEmpty);

    await chooseFile(tester, 'old.xls', [1, 2], button: 'Choose another file');
    expect(find.text('Choose an .xlsx or .csv file.'), findsOneWidget);

    await chooseFile(tester, 'almeco.csv', utf8.encode(_csv), button: 'Choose another file');
    expect(find.text('Reading file…'), findsOneWidget);
  });

  testWidgets('phone: rows as cards, buttons stacked, nothing overflows', (tester) async {
    await pumpPage(tester, size: const Size(390, 844));
    await chooseCompany(tester);
    await chooseFile(tester, 'almeco.csv', utf8.encode(_csv));
    api.checkSucceeds(const [EmployeeImportProblem(row: 3, kind: EmployeeImportProblemKind.lastNameMissing)]);
    await tester.pump();

    expect(find.text('3 rows in file · 2 ready to import · 1 with a problem'), findsOneWidget);
    expect(find.text('Row 3'), findsOneWidget);
    expect(find.byType(JitanDataTable), findsNothing);
    expect(find.text('Import 2 employees'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
