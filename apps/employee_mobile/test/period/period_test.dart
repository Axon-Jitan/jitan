import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:employee_mobile/src/period/period_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_jitan_server.dart';

/// Period (Figma 35:57, 48:2, 48:49, 398:6, 99:56, 99:121, 100:2), against
/// the fake server. "Today" is Thursday 22 October 2026.
void main() {
  late TestHarness h;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 22, 9);
    h = TestHarness(clock: () => now);
    h.server.issuedTokens.add('stored-token');
    h.store.values
      ..['session.token'] = 'stored-token'
      ..['session.expiresAt'] = '2099-01-01T00:00:00.000Z';
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 logical
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EmployeeApp(services: h.services));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, String text, {bool last = false}) async {
    final finder = last ? find.text(text).last : find.text(text).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> view(WidgetTester tester, String name) async {
    await tester.tap(find.byType(PeriodViewSelector));
    await settle(tester);
    await tap(tester, name, last: true);
  }

  /// Wednesday 21 October: started 08:00, no finish.
  void missingFinishYesterday() {
    h.server.pastDays['2026-10-21'] = (
      {
        'employeeId': 1,
        'employeeCode': '',
        'date': '2026-10-21',
        'status': 'missing_finish',
        'start': {
          'actualId': 90,
          'actual': '2026-10-21T06:03:00.000Z',
          'rounded': '2026-10-21T06:00:00.000Z',
          'method': 'manual',
          'enteredByHand': false,
          'actualLocal': '08:03',
          'roundedLocal': '08:00',
        },
        'events': [
          {'atLocal': '08:03', 'boundary': 'start', 'kind': 'registered', 'active': true, 'method': 'manual'},
        ],
      },
      null,
    );
  }

  testWidgets('Period from the bar: this day, registered so far and today\'s timeline', (tester) async {
    await startApp(tester);
    await tap(tester, 'Start work');
    now = DateTime(2026, 10, 22, 11, 30);

    await tap(tester, 'Period');
    expect(find.text('Thursday, 22 October'), findsOneWidget);
    expect(find.text('This day'), findsOneWidget);
    expect(find.text('2h 30m'), findsOneWidget);
    expect(find.text('registered so far'), findsOneWidget);
    expect(find.text('WORKING'), findsOneWidget);
    expect(find.text('Work started'), findsOneWidget);

    await tap(tester, 'Home');
    expect(find.text('You’re working.'), findsOneWidget);
  });

  testWidgets('a correction waiting for HR says so in the timeline; once approved it does not', (tester) async {
    h.server.registrations.add({'boundary': 'start', 'entry': 'corrected', 'at': DateTime(2026, 10, 22, 8).toUtc().toIso8601String(), 'reason': 'Forgot'});
    h.server.firstDay = false;
    await startApp(tester);
    await tap(tester, 'Period');
    expect(find.text('Start corrected'), findsOneWidget);
    expect(find.text('Waiting for HR approval'), findsOneWidget);

    // Approved: the request stays in the timeline as history, no longer waiting.
    h.server.registrations.single['entry'] = 'now';
    await view(tester, 'This week');
    await view(tester, 'This day');
    expect(find.text('Waiting for HR approval'), findsNothing);
  });

  testWidgets('this week: the total, a bar per day, the daily records and Day details', (tester) async {
    h.server.pastDays['2026-10-20'] = (
      {'employeeId': 1, 'employeeCode': '', 'date': '2026-10-20', 'status': 'complete', 'events': <Object?>[]},
      450,
    );
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'This week');

    expect(find.text('19–25 October 2026'), findsOneWidget);
    expect(find.text('REGISTERED THIS WEEK'), findsOneWidget);
    expect(find.text('7h 30m'), findsWidgets, reason: 'the week total and Tuesday');
    expect(find.text('Daily registered hours'), findsOneWidget);
    expect(find.text('Tue 20'), findsOneWidget);
    expect(find.text('Fri 23'), findsNothing, reason: 'no future days in the records');

    await tap(tester, 'Tue 20');
    expect(find.text('Day details'), findsOneWidget);
    expect(find.text('Tuesday, 20 October 2026'), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
  });

  testWidgets('this month: planned and registered, the calendar and its legend', (tester) async {
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'This month');

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Planned'), findsWidgets);
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('176h'), findsOneWidget, reason: '22 weekdays × 8h');
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('a missing finish yesterday: Day details offers to add it; it goes to HR', (tester) async {
    missingFinishYesterday();
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'This week');
    expect(find.text('MISSING FINISH'), findsOneWidget, reason: 'in the daily records');

    await tap(tester, 'Wed 21');
    expect(find.text('Actual 08:03 — --:--'), findsOneWidget);
    await tap(tester, 'Add your finish time');

    expect(find.text('Missing end time'), findsOneWidget);
    expect(find.text('Actual: 08:03'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Send to HR');
    expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'no comment yet');

    await tester.enterText(find.byType(TextField).last, 'Forgot to tap Finish.');
    await tester.pump();
    await tap(tester, 'Send to HR');

    final sent = h.server.registrations.single;
    expect((sent['boundary'], sent['entry'], sent['reason']), ('finish', 'corrected', 'Forgot to tap Finish.'));
    expect(sent['at'], DateTime(2026, 10, 21, 16, 30).toUtc().toIso8601String(), reason: 'the scheduled finish, on that day');
    expect(find.text('Missing end time'), findsNothing);
  });

  testWidgets('a day without activity, and the arrows stop at today', (tester) async {
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'This week');
    await tap(tester, 'Mon 19');

    await tester.tap(find.byTooltip('Previous day'));
    await settle(tester);
    await tester.tap(find.byTooltip('Previous day'));
    await settle(tester);
    expect(find.text('Saturday, 17 October 2026'), findsOneWidget);
    expect(find.text('No activity for this day'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Next day'));
      await settle(tester);
    }
    expect(find.text('Thursday, 22 October 2026'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull, reason: 'no future days');
  });
}
