import 'dart:convert';

import 'package:admin_web/src/period/period_button.dart';
import 'package:admin_web/src/reports/report_export.dart';
import 'package:admin_web/src/reports/reports_screen.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_reports.dart';

const _titles = ['Code', 'First name', 'Last name', 'Planned', 'Worked', 'Difference', 'Travel', 'Days to review'];

void main() {
  late FakeReportsApi api;
  late MemorySessionStore store;
  late List<(String, List<int>, String)> downloads;

  setUp(() {
    downloads = [];
    store = MemorySessionStore();
    api = FakeReportsApi()
      ..employees = [
        reportEmployee(1, 'Kevin', 'De Vos', 'KDV', registered: 9960),
        reportEmployee(
          2,
          'Fabian',
          'Peeters',
          'FPT',
          registered: 8460,
          toReview: 3,
          days: [
            HoursReportDay(date: DateTime.utc(2026, 10, 21), status: TimeRecordStatus.missingFinish, start: '08:00'),
            HoursReportDay(
              date: DateTime.utc(2026, 10, 19),
              status: TimeRecordStatus.complete,
              start: '08:00',
              finish: '16:30',
              registeredMinutes: 360,
              awayMinutes: 120,
            ),
          ],
        ),
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
            store: store,
            today: () => DateTime(2026, 10, 23),
            download: (name, bytes, type) => downloads.add((name, bytes, type)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The period picker's "Last month" (Figma `1475:16`): September 2026.
  Future<void> pickLastMonth(WidgetTester tester) async {
    await tester.tap(find.byType(PeriodButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
  }

  testWidgets('kilometres: a dash without trips, and the note only when a distance is short', (tester) async {
    await pump(tester);
    expect(find.text('Kilometres'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining('A distance in amber'), findsNothing);

    api.employees = [reportEmployee(1, 'Kevin', 'De Vos', 'KDV', trips: 40, metres: 1267600, unknownTrips: 1)];
    await pickLastMonth(tester);

    expect(find.text('1 268 km'), findsOneWidget);
    expect(find.textContaining('A distance in amber'), findsOneWidget);
  });

  testWidgets('the period: this month up to today at first, totals, one row per employee, and what to review', (tester) async {
    await pump(tester);

    expect(api.calls.single, (DateTime(2026, 10), DateTime(2026, 10, 23), null));
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('1 – 23 Oct 2026'), findsOneWidget);
    expect(find.text('320h'), findsOneWidget, reason: 'planned');
    expect(find.text('+6h'), findsOneWidget);
    expect(find.text('−19h'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.textContaining('2 employees.'), findsOneWidget);
  });

  testWidgets('a row opens the employee\'s days, with the time away', (tester) async {
    await pump(tester);

    await tester.tap(find.textContaining('Fabian Peeters'));
    await tester.pumpAndSettle();

    expect(find.text('1 – 23 Oct 2026 · FPT'), findsOneWidget);
    expect(find.text('Wed 21 October'), findsOneWidget);
    expect(find.text('Missing finish'), findsOneWidget);
    expect(find.text('Time away 2h'), findsOneWidget);
    expect(find.text('6h'), findsOneWidget);
  });

  testWidgets('search filters the rows and the totals', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'kdv');
    await tester.pumpAndSettle();

    expect(find.textContaining('Fabian'), findsNothing);
    expect(find.text('160h'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pumpAndSettle();
    expect(find.text('No employees match your search.'), findsOneWidget);
  });

  testWidgets('another period loads from the server and is remembered; an empty one says so and offers no export', (tester) async {
    api.emptyMonths = {'2026-09'};
    await pump(tester);

    await pickLastMonth(tester);

    expect(api.calls.last, (DateTime(2026, 9), DateTime(2026, 9, 30), null));
    expect(store.read('jitan.reports.period'), 'lastMonth');
    expect(find.text('Nothing registered in this period'), findsOneWidget);
    expect(tester.widget<JitanPrimaryButton>(find.byType(JitanPrimaryButton)).onPressed, isNull);
  });

  testWidgets('a failed load says so and retries', (tester) async {
    api.fail = const ApiClientException.server(500, ApiError(code: 'internal_error', message: 'x'));
    await pump(tester);
    expect(find.text('Unable to load the report. Try again →'), findsOneWidget);

    api.fail = null;
    await tester.tap(find.text('Unable to load the report. Try again →'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 employees.'), findsOneWidget);
  });

  testWidgets('export: Excel and CSV of what is on screen, named by period', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excel (.xlsx)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CSV (.csv)'));
    await tester.pumpAndSettle();

    expect(downloads.map((d) => d.$1), ['jitan-hours-2026-10-01_2026-10-23.xlsx', 'jitan-hours-2026-10-01_2026-10-23.csv']);
  });

  group('the file', () {
    final emma = reportEmployee(
      1,
      'Émma',
      'Janssens',
      'EJA',
      planned: 9600,
      registered: 9450,
      toReview: 1,
      trips: 4,
      metres: 96450,
      unknownTrips: 1,
      travel: 75,
    );

    test('Excel: titles, then hours as numbers', () {
      final book = Excel.decodeBytes(ReportExport.excel(_titles, [emma]));
      final rows = book.tables[book.getDefaultSheet()!]!.rows;

      expect(rows[0].first?.value.toString(), 'Code');
      expect(rows[1].map((c) => c?.value.toString()), ['EJA', 'Émma', 'Janssens', '160', '157.5', '-2.5', '1.25', '1', '4', '96.5', '1']);
    });

    test('CSV: semicolons, and é survives', () {
      final bytes = ReportExport.csv(_titles, [emma]);

      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.skip(3).toList()).split('\r\n')[1], 'EJA;Émma;Janssens;160.0;157.5;-2.5;1.25;1;4;96.5;1');
    });

    test('CSV: a name can not become a formula or a new column', () {
      final hostile = reportEmployee(2, '=HYPERLINK("x")', 'De;Vos', '+KDV');

      final line = utf8.decode(ReportExport.csv(_titles, [hostile]).skip(3).toList()).split('\r\n')[1];

      expect(line, startsWith("'+KDV;\"'=HYPERLINK(\"\"x\"\")\";\"De;Vos\";"));
    });
  });
}
