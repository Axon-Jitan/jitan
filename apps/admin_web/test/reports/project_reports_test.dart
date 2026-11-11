import 'dart:convert';

import 'package:admin_web/src/period/period_button.dart';
import 'package:admin_web/src/reports/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_reports.dart';

void main() {
  late FakeReportsApi api;
  late List<(String, List<int>, String)> downloads;

  setUp(() {
    downloads = [];
    api = FakeReportsApi()
      ..projectRows = [
        reportProject(
          3,
          'P-1042',
          'Office refurbishment',
          worked: 18750,
          travel: 1120,
          trips: 9,
          metres: 412000,
          employees: const [
            ProjectReportEmployee(
              employeeId: 1,
              firstName: 'Hanne',
              lastName: 'Claes',
              code: 'CLH',
              days: 12,
              workedMinutes: 5760,
              travelMinutes: 310,
              trips: 3,
            ),
          ],
        ),
        reportProject(4, 'P-0990', 'Clean the workshop', place: 'Almeco', client: false, worked: 2475),
      ];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: Scaffold(
          body: ReportsScreen(
            api: api,
            companiesApi: FakeCompaniesApi(),
            today: () => DateTime(2026, 10, 23),
            download: (name, bytes, type) => downloads.add((name, bytes, type)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openProjects(WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
  }

  testWidgets('Employees first; Projects loads the project report for the same period (Figma 1515:2)', (tester) async {
    await pump(tester);
    expect(api.projectCalls, isEmpty, reason: 'loaded only when shown');

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(api.projectCalls, [(DateTime(2026, 10), DateTime(2026, 10, 23))]);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Worked hours and travel per project, for invoicing.'), findsOneWidget);
    expect(find.text('Company'), findsNothing, reason: 'a project has no company');
    expect(find.textContaining('P-1042 Office refurbishment'), findsOneWidget);
    expect(find.text('412 km'), findsWidgets);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'two projects in the totals');
    expect(find.textContaining('2 projects.'), findsOneWidget);
  });

  testWidgets('without trips: dashes for travel, trips and kilometres', (tester) async {
    await openProjects(tester);
    expect(find.text('—'), findsNWidgets(3));
  });

  testWidgets('search narrows by SAP number or name', (tester) async {
    await openProjects(tester);

    await tester.enterText(find.byType(TextField), 'p-0990');
    await tester.pumpAndSettle();
    expect(find.textContaining('P-0990 Clean the workshop'), findsOneWidget);
    expect(find.textContaining('P-1042'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like it');
    await tester.pumpAndSettle();
    expect(find.text('No projects match your search.'), findsOneWidget);
  });

  testWidgets('a row opens the project’s month: its numbers and each employee (Figma 1515:190)', (tester) async {
    await openProjects(tester);

    await tester.tap(find.textContaining('P-1042 Office refurbishment'));
    await tester.pumpAndSettle();

    expect(find.text('1 – 23 Oct 2026 · Client site · Mouscron'), findsOneWidget);
    expect(find.textContaining('Hanne Claes'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('96h'), findsOneWidget);
    expect(find.text('5h 10m'), findsOneWidget);
  });

  testWidgets('a new period reloads both reports', (tester) async {
    await openProjects(tester);

    await tester.tap(find.byType(PeriodButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final september = (DateTime(2026, 9), DateTime(2026, 9, 30));
    expect(api.projectCalls.last, september);
    expect((api.calls.last.$1, api.calls.last.$2), september);
  });

  testWidgets('a period without project time says so', (tester) async {
    api.emptyMonths = {'2026-10'};
    await openProjects(tester);
    expect(find.text('No project time in this period'), findsOneWidget);
  });

  testWidgets('a failure, with a retry', (tester) async {
    await pump(tester);
    api.fail = const ApiClientException.network('down');
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load the report. Try again →'), findsOneWidget);
  });

  testWidgets('export: one row per project, as CSV', (tester) async {
    await openProjects(tester);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV (.csv)'));
    await tester.pumpAndSettle();

    final (name, bytes, _) = downloads.single;
    expect(name, 'jitan-projects-2026-10-01_2026-10-23.csv');
    final lines = utf8.decode(bytes.skip(3).toList()).trim().split('\r\n');
    expect(lines.first, 'SAP number;Project;Place;Employees;Worked hours;Travel hours;Trips;Kilometres;Trips without a distance');
    expect(lines[1], 'P-1042;Office refurbishment;Mouscron;1;312.5;18.67;9;412.0;0');
    expect(lines, hasLength(3));
  });
}
