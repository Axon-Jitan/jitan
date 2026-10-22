import 'package:admin_web/src/time_records/time_records_controller.dart';
import 'package:admin_web/src/time_records/time_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_time_records_api.dart';

/// Thursday 22 October 2026.
DateTime _today() => DateTime(2026, 10, 22, 15);

final _complete = recordDay(
  1,
  'Disan',
  'Ssebowa',
  'SBW',
  DateTime.utc(2026, 10, 21),
  TimeRecordStatus.complete,
  start: recordTime('07:58', rounded: '08:00'),
  finish: recordTime('16:31', rounded: '16:30', method: TimeRecordMethod.manual, byHand: true, reason: 'Forgot to tap'),
);
final _missing = recordDay(
  2,
  'Kevin',
  'De Vos',
  'KDV',
  DateTime.utc(2026, 10, 20),
  TimeRecordStatus.missingFinish,
  start: recordTime('08:03', rounded: '08:15'),
);
final _working = recordDay(
  3,
  'Fabian',
  'Peeters',
  'FPT',
  DateTime.utc(2026, 10, 22),
  TimeRecordStatus.working,
  start: recordTime('08:01', rounded: '08:15', method: TimeRecordMethod.geofence),
);

Future<(FakeTimeRecordsApi, FakeCompaniesApi)> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeTimeRecordsApi();
  final companies = FakeCompaniesApi();
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: Scaffold(body: TimeRecordsScreen(api: api, companiesApi: companies, today: _today)),
      ),
    ),
  );
  companies.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
  await tester.pump();
  return (api, companies);
}

void main() {
  group('periods', () {
    test('weeks start on Monday; months run to their last day', () {
      final today = DateTime(2026, 10, 22);
      expect(TimeRecordsController.rangeOf(TimeRecordPeriod.thisWeek, today), (DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 25)));
      expect(TimeRecordsController.rangeOf(TimeRecordPeriod.lastWeek, today), (DateTime.utc(2026, 10, 12), DateTime.utc(2026, 10, 18)));
      expect(TimeRecordsController.rangeOf(TimeRecordPeriod.thisMonth, today), (DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 31)));
      expect(TimeRecordsController.rangeOf(TimeRecordPeriod.lastMonth, today), (DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 30)));
      expect(
        TimeRecordsController.rangeOf(TimeRecordPeriod.lastMonth, DateTime(2027, 1, 5)),
        (DateTime.utc(2026, 12, 1), DateTime.utc(2026, 12, 31)),
        reason: 'across the year',
      );
    });
  });

  testWidgets('loads this week for every company and shows each day as in Figma 160:2', (tester) async {
    final (api, _) = await _pump(tester);
    expect(api.calls.single, (DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 25), null, ''));

    api.succeed([_working, _complete, _missing]);
    await tester.pump();

    for (final header in ['Date', 'Rounded time', 'Actual time', 'Method', 'Action']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Employee'), findsNWidgets(2), reason: 'the filter and the column');
    expect(find.text('Wed 21 Oct'), findsOneWidget);
    expect(find.text('08:00–16:30'), findsOneWidget);
    expect(find.text('07:58–16:31'), findsOneWidget);
    expect(find.text('08:15–—'), findsNWidgets(2), reason: 'no finish yet');
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Missing finish'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('View'), findsNWidgets(3));
  });

  testWidgets('the status filter narrows the loaded days; company and period reload; Reset all', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([_working, _complete, _missing]);
    await tester.pump();

    tester.widget<JitanSelectField<TimeRecordStatus?>>(find.byType(JitanSelectField<TimeRecordStatus?>)).onChanged!(
      TimeRecordStatus.missingFinish,
    );
    await tester.pump();
    expect(find.text('Kevin De Vos'), findsOneWidget);
    expect(find.text('Disan Ssebowa'), findsNothing);
    expect(api.calls, hasLength(1), reason: 'the status needs no reload');

    tester.widget<JitanSelectField<int?>>(find.byType(JitanSelectField<int?>)).onChanged!(7);
    await tester.pump();
    expect(api.calls.last.$3, 7);
    api.succeed([]);
    await tester.pump();

    tester.widget<JitanSelectField<TimeRecordPeriod>>(find.byType(JitanSelectField<TimeRecordPeriod>)).onChanged!(
      TimeRecordPeriod.lastMonth,
    );
    await tester.pump();
    expect((api.calls.last.$1, api.calls.last.$2), (DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 30)));
    api.succeed([]);
    await tester.pump();
    expect(find.text('No matching records'), findsOneWidget, reason: 'filters are set');

    await tester.tap(find.text('Reset all'));
    await tester.pump();
    expect(api.calls.last, (DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 25), null, ''));
  });

  testWidgets('View opens the day: actual and rounded start and finish, and why a time was entered afterwards', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([_complete, _missing]);
    await tester.pump();

    await tester.tap(find.text('View').first);
    await tester.pumpAndSettle();

    expect(find.text('Time record'), findsOneWidget);
    expect(find.text('Disan Ssebowa · Wednesday, 21 October 2026'), findsOneWidget);
    expect(find.text('Work start'), findsOneWidget);
    expect(find.text('07:58'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
    expect(find.text('Entered afterwards: Forgot to tap'), findsOneWidget);
    expect(find.text('Rounded times use applicable schedule rules. Original timestamps are preserved.'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View').last);
    await tester.pumpAndSettle();
    expect(find.text('Not registered'), findsOneWidget, reason: 'missing finish');
  });

  testWidgets('empty period, and a failure with retry', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([]);
    await tester.pump();
    expect(find.text('No time records'), findsOneWidget);

    tester.widget<JitanSelectField<TimeRecordPeriod>>(find.byType(JitanSelectField<TimeRecordPeriod>)).onChanged!(
      TimeRecordPeriod.lastWeek,
    );
    await tester.pump();
    api.fail(const ApiClientException.network('offline'));
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(api.calls, hasLength(3));
  });
}
