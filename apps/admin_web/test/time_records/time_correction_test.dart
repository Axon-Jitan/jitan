import 'package:admin_web/src/time_records/time_correction_fields.dart';
import 'package:admin_web/src/time_records/time_input_formatter.dart';
import 'package:admin_web/src/time_records/time_records_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_time_records_api.dart';

/// HR corrections from Time records (Figma `1566:272`, `1566:529`,
/// `1566:788`, `1566:1040`; TIME_ENGINE_ANALYSIS D7, D31).

final _complete = recordDay(
  1,
  'Disan',
  'Ssebowa',
  'SBW',
  DateTime.utc(2026, 10, 21),
  TimeRecordStatus.complete,
  start: recordTime('07:58', rounded: '08:00'),
  finish: recordTime('16:31', rounded: '16:30'),
  events: const [
    TimeRecordEvent(atLocal: '07:58', boundary: RegistrationBoundary.start, kind: TimeRecordEventKind.registered, active: true, method: TimeRecordMethod.qr),
    TimeRecordEvent(atLocal: '16:31', boundary: RegistrationBoundary.finish, kind: TimeRecordEventKind.registered, active: true, method: TimeRecordMethod.qr),
  ],
);
final _missingFinish = recordDay(
  2,
  'Fabian',
  'Peeters',
  'FPT',
  DateTime.utc(2026, 10, 20),
  TimeRecordStatus.missingFinish,
  start: recordTime('08:03', rounded: '08:00'),
);
final _pendingStart = recordDay(
  4,
  'Thomas',
  'Vermeulen',
  'TVM',
  DateTime.utc(2026, 10, 19),
  TimeRecordStatus.pendingReview,
  start: recordTime('07:01', rounded: '07:00'),
  finish: recordTime('15:32', rounded: '15:30'),
  pending: [
    TimeRecordPending(
      id: 55,
      boundary: RegistrationBoundary.start,
      requested: DateTime.utc(2026, 10, 19, 5),
      requestedLocal: '07:00',
      reason: 'Forgot to scan immediately after arriving at the van.',
      roundedLocal: '07:00',
    ),
  ],
);

Future<(FakeTimeRecordsApi, FakeCompaniesApi)> _pump(WidgetTester tester, List<TimeRecordDay> days) async {
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
        home: Scaffold(body: TimeRecordsScreen(api: api, companiesApi: companies, today: () => DateTime(2026, 10, 22, 15))),
      ),
    ),
  );
  companies.succeed([company(7, 'Almeco'), company(8, 'PCA')]);
  api.succeed(days);
  await tester.pump();
  await tester.pump();
  return (api, companies);
}

/// A row: straight to its Fix or Review, else to the day.
Future<void> _open(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The time in the card's [index]th input (0: the first row's).
Future<void> _time(WidgetTester tester, int index, String text) async {
  await tester.enterText(find.descendant(of: find.byType(TimeCardInput).at(index), matching: find.byType(TextField)), text);
  await tester.pump();
}

Future<void> _reason(WidgetTester tester, String text) async {
  await tester.enterText(find.descendant(of: find.widgetWithText(JitanTextField, 'Reason'), matching: find.byType(TextField)), text);
  await tester.pump();
}

/// The pop-up's white surface.
Size _popupSize(WidgetTester tester) =>
    tester.getSize(find.descendant(of: find.byType(Dialog).last, matching: find.byType(Material)).first);

void main() {
  test('a typed time is arranged as HH:mm', () {
    String typed(String text) =>
        const TimeInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text)).text;
    expect([typed('8'), typed('08'), typed('083'), typed('0830'), typed('08:30'), typed('08305'), typed('a1b2')], [
      '8',
      '08',
      '08:3',
      '08:30',
      '08:30',
      '08:30',
      '12',
    ]);
  });

  testWidgets('Fix: the rounded time comes from the server, a reason is required, then a toast and the list reloads (Figma 1566:272)', (tester) async {
    final (api, _) = await _pump(tester, [_missingFinish]);
    await _open(tester, 'Fix');

    expect(find.text('Missing finish'), findsNWidgets(2), reason: 'the row and the title');
    expect(find.text('Fabian Peeters · Tuesday 20 October'), findsOneWidget);
    expect(find.text('08:03'), findsOneWidget, reason: 'the start that is there');

    api.previewAnswer = '16:30';
    await _time(tester, 0, '1622');
    await tester.pump();
    expect(api.previews, ['finish 16:22']);
    expect(find.text('16:30'), findsOneWidget, reason: 'rounded by the server');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Give the reason for this correction.'), findsOneWidget);
    expect(api.writes, isEmpty);

    await _reason(tester, 'Employee confirmed with HR');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(api.writes, ['correct 7/2 2026-10-20 finish 16:22 Employee confirmed with HR']);
    api.writeSucceeds();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Finish added for Fabian Peeters.'), findsOneWidget);
    expect(api.calls, hasLength(2), reason: 'the list reloads');
  });

  testWidgets('Not a work day keeps the pop-up\'s size; a day with nothing to mark (Figma 1566:529)', (tester) async {
    final (api, _) = await _pump(tester, [_missingFinish]);
    await _open(tester, 'Fix');
    final size = _popupSize(tester);
    expect(size.width, 560);

    await tester.tap(find.text('Not a work day'));
    await tester.pump();
    expect(_popupSize(tester), size, reason: 'switching never makes it jump');
    expect(find.text('The day won’t count as work. Its start stays in the history.'), findsOneWidget);
    expect(find.byType(TimeCardInput), findsNothing);

    await _reason(tester, 'Confirmed non-working day');
    await tester.tap(find.text('Save as not a work day'));
    await tester.pump();
    expect(api.writes, ['nonWork 7/2 2026-10-20 Confirmed non-working day']);
    api.writeFails(
      const ApiClientException.server(409, ApiError(code: ApiErrorCode.nothingToMarkNonWork, message: 'x')),
    );
    await tester.pump();
    expect(find.text('There is no registration on this day to mark as non-work.'), findsOneWidget);

    await tester.tap(find.text('Save as not a work day'));
    await tester.pump();
    api.writeSucceeds();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Marked as not a work day for Fabian Peeters.'), findsOneWidget);
  });

  testWidgets('Review → approve the employee correction (D31, Figma 1566:1040)', (tester) async {
    final (api, _) = await _pump(tester, [_pendingStart]);
    expect(find.text('Pending review'), findsOneWidget);
    await _open(tester, 'Review');

    expect(find.text('Review correction'), findsOneWidget);
    expect(find.text('Thomas Vermeulen · Monday 19 October · asked by the employee'), findsOneWidget);
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Asked'), findsOneWidget);
    expect(find.text('Rounded'), findsNWidgets(2), reason: 'the card, and the list behind');
    expect(find.text('07:01'), findsOneWidget, reason: 'registered');
    expect(find.text('07:00'), findsNWidgets(2), reason: 'asked, and what it counts as');
    expect(find.text('“Forgot to scan immediately after arriving at the van.”'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pump();
    expect(api.writes, ['approve 7/4 55']);
    api.writeSucceeds();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Correction approved for Thomas Vermeulen.'), findsOneWidget);
  });

  testWidgets('Reject, and a failure keeps the pop-up open', (tester) async {
    final (api, _) = await _pump(tester, [_pendingStart]);
    await _open(tester, 'Review');

    await tester.tap(find.text('Reject'));
    await tester.pump();
    api.writeFails(const ApiClientException.network('offline'));
    await tester.pump();
    expect(find.text('Review correction'), findsOneWidget);
    expect(find.textContaining('connect'), findsWidgets);

    await tester.tap(find.text('Reject'));
    await tester.pump();
    expect(api.writes, ['reject 7/4 55', 'reject 7/4 55']);
    api.writeSucceeds();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Correction rejected for Thomas Vermeulen.'), findsOneWidget);
  });

  testWidgets('a day → Correct time, the same size: only the changed time is saved; a refused time shows under the card', (tester) async {
    final (api, _) = await _pump(tester, [_complete]);
    await _open(tester, 'Disan Ssebowa');
    final size = _popupSize(tester);

    await tester.tap(find.text('Show what happened'));
    await tester.pump();
    expect(find.text('Start registered · QR'), findsOneWidget);
    expect(find.text('Finish registered · QR'), findsOneWidget);
    expect(_popupSize(tester), size, reason: 'what happened opens inside');

    await tester.tap(find.text('Correct time'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Correct time'), findsOneWidget);
    expect(_popupSize(tester), size, reason: 'from the day to its correction, nothing jumps');

    await _reason(tester, 'Left later');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Change a time first.'), findsOneWidget);

    await _time(tester, 1, '1645');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(api.writes, ['correct 7/1 2026-10-21 finish 16:45 Left later']);
    api.writeFails(
      const ApiClientException.server(400, ApiError(code: ApiErrorCode.validationFailed, message: 'x', field: 'time')),
    );
    await tester.pump();
    expect(find.text('This time is not possible: it is in the future or not on this day.'), findsOneWidget);

    await _time(tester, 1, '1640');
    await tester.tap(find.text('Save'));
    await tester.pump();
    api.writeSucceeds();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Time corrected for Disan Ssebowa.'), findsOneWidget);
  });

  testWidgets('a correction is made in the filtered company when the employee belongs to it', (tester) async {
    final both = recordDay(2, 'Fabian', 'Peeters', 'FPT', DateTime.utc(2026, 10, 20), TimeRecordStatus.missingFinish,
        start: recordTime('08:03', rounded: '08:00'), companyIds: const [7, 8]);
    final (api, _) = await _pump(tester, [both]);
    tester.widget<JitanFilterSelect<int?>>(find.byType(JitanFilterSelect<int?>)).onChanged(8);
    await tester.pump();
    api.succeed([both]);
    await tester.pump();

    await _open(tester, 'Fix');
    await tester.tap(find.text('Not a work day'));
    await tester.pump();
    await _reason(tester, 'Holiday');
    await tester.tap(find.text('Save as not a work day'));
    await tester.pump();
    expect(api.writes.single, startsWith('nonWork 8/2'));
  });
}
