import 'package:admin_web/src/time_records/time_records_controller.dart';
import 'package:admin_web/src/time_records/time_record_status_filter.dart';
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

Future<(FakeTimeRecordsApi, FakeCompaniesApi)> _pump(
  WidgetTester tester, {
  TimeRecordStatusFilter? status,
  ({DateTime from, DateTime to})? range,
}) async {
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
        home: Scaffold(
          body: TimeRecordsScreen(api: api, companiesApi: companies, today: _today, status: status, range: range),
        ),
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

  testWidgets('loads this week for every company and shows the days grouped, newest first (Figma 1565:2)', (tester) async {
    final (api, _) = await _pump(tester);
    expect(api.calls.single, (DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 25), null, ''));

    api.succeed([_working, _complete, _missing]);
    await tester.pump();
    await tester.pump();

    expect(find.text('This week · 19 – 25 Oct 2026 · 1 day to review'), findsOneWidget);
    for (final header in ['Employee', 'Rounded', 'Actual', 'How', 'Status']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    for (final heading in ['Today', 'Thursday 22 October', 'Yesterday', 'Wednesday 21 October', 'Tuesday', '20 October']) {
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
    expect(find.text('1 working'), findsOneWidget);
    expect(find.text('1 finished'), findsOneWidget);
    expect(find.text('1 to review'), findsOneWidget);
    expect(find.text('08:00 – 16:30'), findsOneWidget);
    expect(find.text('07:58 – 16:31'), findsOneWidget);
    expect(find.text('08:15 – …'), findsOneWidget, reason: 'still working');
    expect(find.text('08:15 – —'), findsOneWidget, reason: 'no finish');
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Missing finish'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
    expect(find.text('Fix'), findsOneWidget, reason: 'only the missing finish asks HR to act');
    expect(find.text('View'), findsNothing);
    expect(find.text('Clear'), findsNothing, reason: 'nothing is filtered');
  });

  testWidgets('Show narrows the loaded days; company and period reload; Clear', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([_working, _complete, _missing]);
    await tester.pump();
    await tester.pump();

    tester.widget<JitanFilterSelect<TimeRecordStatusFilter?>>(find.byType(JitanFilterSelect<TimeRecordStatusFilter?>)).onChanged(
      const TimeRecordStatusFilter.only(TimeRecordStatus.missingFinish),
    );
    await tester.pump();
    expect(find.text('Kevin De Vos'), findsOneWidget);
    expect(find.text('Disan Ssebowa'), findsNothing);
    expect(api.calls, hasLength(1), reason: 'the status needs no reload');

    tester.widget<JitanFilterSelect<int?>>(find.byType(JitanFilterSelect<int?>)).onChanged(7);
    await tester.pump();
    expect(api.calls.last.$3, 7);
    api.succeed([]);
    await tester.pump();
    await tester.pump();

    tester.widget<JitanFilterSelect<TimeRecordPeriod?>>(find.byType(JitanFilterSelect<TimeRecordPeriod?>)).onChanged(
      TimeRecordPeriod.lastMonth,
    );
    await tester.pump();
    expect((api.calls.last.$1, api.calls.last.$2), (DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 30)));
    api.succeed([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('No matching records'), findsOneWidget, reason: 'filters are set');

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(api.calls.last, (DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 25), null, ''));
  });

  testWidgets('a row opens its day: actual and rounded start and finish, and why a time was entered afterwards (Figma 1566:2)', (tester) async {
    final (api, _) = await _pump(tester);
    // Without a company to correct in, a missing finish can only be looked at.
    final missingNoCompany = recordDay(2, 'Kevin', 'De Vos', 'KDV', DateTime.utc(2026, 10, 20), TimeRecordStatus.missingFinish,
        start: recordTime('08:03', rounded: '08:15'), companyIds: const []);
    api.succeed([_complete, missingNoCompany]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Fix'), findsNothing, reason: 'no company to correct it in');

    await tester.tap(find.text('Disan Ssebowa'));
    await tester.pumpAndSettle();

    expect(find.text('Disan Ssebowa'), findsNWidgets(2), reason: 'the row and the title');
    expect(find.text('Wednesday 21 October · Registered'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('07:58'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
    expect(find.text('Employee\nEntered afterwards: Forgot to tap'), findsOneWidget);
    expect(find.text('Rounded with the schedule’s rules. What was registered is always kept.'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kevin De Vos'));
    await tester.pumpAndSettle();
    expect(find.text('Not registered'), findsOneWidget, reason: 'missing finish');
    expect(find.text('Correct time'), findsNothing, reason: 'no company to correct it in');
  });

  testWidgets('empty period, and a failure with retry', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([]);
    await tester.pump();
    await tester.pump();
    expect(find.text('No time records'), findsOneWidget);

    tester.widget<JitanFilterSelect<TimeRecordPeriod?>>(find.byType(JitanFilterSelect<TimeRecordPeriod?>)).onChanged(
      TimeRecordPeriod.lastWeek,
    );
    await tester.pump();
    expect(find.text('Loading time records…'), findsOneWidget);
    api.fail(const ApiClientException.network('offline'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Unable to load time records. Try again →'));
    await tester.pump();
    expect(api.calls, hasLength(3));
  });

  testWidgets('opened from the Dashboard: exact days and "To review", until a period is chosen', (tester) async {
    final (api, _) = await _pump(
      tester,
      status: TimeRecordStatusFilter.toReview,
      range: (from: DateTime.utc(2026, 10, 1), to: DateTime.utc(2026, 10, 23)),
    );
    api.succeed([_working, _complete, _missing]);
    await tester.pump();
    await tester.pump();

    expect((api.calls.single.$1, api.calls.single.$2), (DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 23)));
    expect(find.text('1 – 23 Oct 2026'), findsOneWidget, reason: 'the period button');
    expect(find.text('1 – 23 Oct 2026 · 1 day to review'), findsOneWidget);
    expect(find.text('To review'), findsOneWidget);
    expect(find.text('Kevin De Vos'), findsOneWidget, reason: 'the missing finish');
    expect(find.text('Disan Ssebowa'), findsNothing);

    tester.widget<JitanFilterSelect<TimeRecordPeriod?>>(find.byType(JitanFilterSelect<TimeRecordPeriod?>)).onChanged(
      TimeRecordPeriod.thisWeek,
    );
    await tester.pump();
    expect((api.calls.last.$1, api.calls.last.$2), (DateTime.utc(2026, 10, 19), DateTime.utc(2026, 10, 25)));
  });

  test('a link names the status, and only a known one', () {
    expect(TimeRecordStatusFilter.fromWire('to_review'), TimeRecordStatusFilter.toReview);
    expect(
      TimeRecordStatusFilter.fromWire(TimeRecordStatus.pendingReview.wireName),
      const TimeRecordStatusFilter.only(TimeRecordStatus.pendingReview),
    );
    expect(TimeRecordStatusFilter.fromWire('finished'), TimeRecordStatusFilter.finished);
    expect(TimeRecordStatusFilter.fromWire('left_early'), const TimeRecordStatusFilter.attended(DayAttendance.leftEarly));
    expect(TimeRecordStatusFilter.fromWire('not_started'), const TimeRecordStatusFilter.only(TimeRecordStatus.notStarted));
    expect(TimeRecordStatusFilter.fromWire('anything'), isNull);
  });

  test('the attendance filter lets through only those days', () {
    TimeRecordDay day(DayAttendance? attendance) => TimeRecordDay(
      employeeId: 1,
      employeeCode: 'KDV',
      date: DateTime.utc(2026, 10, 21),
      status: TimeRecordStatus.complete,
      attendance: attendance,
    );
    const late = TimeRecordStatusFilter.attended(DayAttendance.late);
    expect([late.lets(day(DayAttendance.late)), late.lets(day(DayAttendance.onTime)), late.lets(day(null))], [true, false, false]);
  });

  testWidgets('a late or left-early day carries a mark after its status; a day on time none (Figma 1521:2)', (tester) async {
    final (api, _) = await _pump(tester);
    api.succeed([
      _complete.copyWith(attendance: DayAttendance.late),
      _working,
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('Late'), findsOneWidget);
    expect(find.text('Left early'), findsNothing);

    tester.widget<JitanFilterSelect<TimeRecordPeriod?>>(find.byType(JitanFilterSelect<TimeRecordPeriod?>)).onChanged(
      TimeRecordPeriod.lastWeek,
    );
    await tester.pump();
    api.succeed([_complete.copyWith(attendance: DayAttendance.onTime)]);
    await tester.pump();
    await tester.pump();
    expect(find.text('On time'), findsNothing, reason: 'on time needs no mark');
  });
}
