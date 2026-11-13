import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:employee_mobile/src/period/period_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';

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
    await tester.tap(find.descendant(of: find.byType(PeriodViewSwitch), matching: find.text(name)));
    await settle(tester);
  }

  Map<String, Object?> time(String date, String local, String utc) => {
    'actualId': 1,
    'actual': '${date}T$utc:00.000Z',
    'rounded': '${date}T$utc:00.000Z',
    'method': 'manual',
    'enteredByHand': false,
    'actualLocal': local,
    'roundedLocal': local,
  };

  /// Tuesday 20 October: 08:00 to 16:00 in the app.
  void completeTuesday() {
    h.server.pastDays['2026-10-20'] = (
      {
        'employeeId': 1,
        'employeeCode': '',
        'date': '2026-10-20',
        'status': 'complete',
        'start': time('2026-10-20', '08:00', '06:00'),
        'finish': time('2026-10-20', '16:00', '14:00'),
        'events': [
          {'atLocal': '08:00', 'boundary': 'start', 'kind': 'registered', 'active': true, 'method': 'manual'},
          {'atLocal': '16:00', 'boundary': 'finish', 'kind': 'registered', 'active': true, 'method': 'manual'},
        ],
      },
      450,
    );
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

  testWidgets('Period from the bar: this day, Home’s total and the timeline with its stamps', (tester) async {
    await startApp(tester);
    await tap(tester, 'Start work');
    now = DateTime(2026, 10, 22, 11, 30);

    await tap(tester, 'Period');
    expect(find.text('Thursday 22 October'), findsOneWidget);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Registered today'), findsOneWidget);
    expect(find.text('2h 30m'), findsOneWidget);
    expect(find.text('Working since 09:00'), findsOneWidget);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Started'), findsOneWidget);
    expect(find.text('In the app'), findsOneWidget);
    expect(find.text('Break · 30 min'), findsNothing, reason: 'the break starts at 12:00, still to come');

    await tap(tester, 'Home');
    expect(find.text('You’re working'), findsOneWidget);
  });

  testWidgets('a correction waiting for HR says so in the timeline; once approved it does not', (tester) async {
    h.server.registrations.add({'boundary': 'start', 'entry': 'corrected', 'at': DateTime(2026, 10, 22, 8).toUtc().toIso8601String(), 'reason': 'Forgot'});
    h.server.firstDay = false;
    await startApp(tester);
    await tap(tester, 'Period');
    expect(find.text('Start corrected'), findsOneWidget);
    expect(find.text('Waiting for HR'), findsOneWidget);
    expect(find.text('“Forgot”'), findsOneWidget, reason: 'the employee’s reason');

    // Approved: the request stays in the timeline as history, no longer waiting.
    h.server.registrations.single['entry'] = 'now';
    await view(tester, 'Week');
    await view(tester, 'Day');
    expect(find.text('Waiting for HR'), findsNothing);
  });

  testWidgets('this week: the total, a bar per day, the days and a day with its stamps', (tester) async {
    completeTuesday();
    h.server.pastActivities['2026-10-20'] = const [
      ActivityEntry(timeLocal: '09:15', kind: ActivityKind.clientOnSite, projectName: 'P-1057 Cooling towers', placeName: 'Engis'),
      ActivityEntry(timeLocal: '13:00', kind: ActivityKind.transport, metres: 36000),
    ];
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'Week');

    expect(find.text('19–25 October 2026'), findsOneWidget);
    expect(find.text('Registered this week'), findsOneWidget);
    expect(find.text('7h 30m'), findsWidgets, reason: 'the week total and Tuesday');
    expect(find.text('Planned 40h'), findsOneWidget);
    expect(find.text('Tue 20'), findsOneWidget);
    expect(find.text('Fri 23'), findsNothing, reason: 'no future days in the list');

    await tap(tester, 'Tue 20');
    expect(find.text('Tuesday 20 October'), findsOneWidget);
    expect(find.text('08:00 – 16:00'), findsOneWidget);
    expect(find.text('Planned 8h 00m · 30 min break'), findsOneWidget);
    // The day's stamps: start, what it went on, the automatic break, finish.
    expect(find.text('Client · On site'), findsOneWidget);
    expect(find.text('P-1057 Cooling towers · Engis'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('36 km'), findsOneWidget);
    expect(find.text('Break · 30 min'), findsOneWidget);
    expect(find.text('Automatic, from your schedule'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    final order = ['08:00', '09:15', '12:00', '13:00', '16:00'].map((t) => tester.getTopLeft(find.text(t)).dy).toList();
    expect(order, [...order]..sort(), reason: 'oldest first');
  });

  testWidgets('time away replaces the break: one stamp, never both (D34)', (tester) async {
    h.server.pastDays['2026-10-20'] = (
      {
        'employeeId': 1,
        'employeeCode': '',
        'date': '2026-10-20',
        'status': 'complete',
        'start': time('2026-10-20', '08:00', '06:00'),
        'finish': time('2026-10-20', '16:00', '14:00'),
        'awayMinutes': 38,
        'events': [
          {'atLocal': '08:00', 'boundary': 'start', 'kind': 'registered', 'active': true, 'method': 'geofence'},
          {'atLocal': '12:03', 'boundary': 'finish', 'kind': 'registered', 'active': true, 'method': 'geofence'},
          {'atLocal': '12:41', 'boundary': 'start', 'kind': 'registered', 'active': true, 'method': 'geofence'},
          {'atLocal': '16:00', 'boundary': 'finish', 'kind': 'registered', 'active': true, 'method': 'geofence'},
        ],
      },
      442,
    );
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'Week');
    await tap(tester, 'Tue 20');

    expect(find.text('7h 22m'), findsOneWidget);
    expect(find.text('Planned 8h 00m · 38 min away instead of the 30 min break'), findsOneWidget);
    expect(find.text('Time away · 38 min'), findsOneWidget);
    expect(find.text('Replaces your break'), findsOneWidget);
    expect(find.text('Break · 30 min'), findsNothing);
    expect(find.text('Started'), findsOneWidget, reason: 'coming back is part of the time away');
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Automatically'), findsNWidgets(2));
  });

  testWidgets('this month: registered and planned, the calendar and its legend', (tester) async {
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'Month');

    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Planned'), findsWidgets);
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('176h'), findsOneWidget, reason: '22 weekdays × 8h');
    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('a missing finish yesterday: the day offers to add it, on a page; it goes to HR', (tester) async {
    missingFinishYesterday();
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'Week');
    expect(find.text('Finish missing'), findsOneWidget, reason: 'in the list, in amber');

    await tap(tester, 'Wed 21');
    expect(find.text('Your finish time is missing.'), findsOneWidget);
    expect(find.text('Not counted yet'), findsOneWidget);
    expect(find.text('Started 08:00 · planned finish 16:30'), findsOneWidget);
    expect(find.text('Break · 30 min'), findsNothing, reason: 'the break counts once the day has a finish');
    await tap(tester, 'Add your finish time');

    expect(find.text('When did you finish?'), findsOneWidget);
    expect(find.text('Wednesday 21 October. You started at 08:03.'), findsOneWidget);
    expect(find.text('Scheduled finish 16:30'), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Send to HR');
    expect(tester.widget<FilledButton>(send).onPressed, isNull, reason: 'no reason yet');

    await tester.enterText(find.byType(TextField).last, 'Forgot to tap Finish.');
    await tester.pump();
    await tap(tester, 'Send to HR');

    final sent = h.server.registrations.single;
    expect((sent['boundary'], sent['entry'], sent['reason']), ('finish', 'corrected', 'Forgot to tap Finish.'));
    expect(sent['at'], DateTime(2026, 10, 21, 16, 30).toUtc().toIso8601String(), reason: 'the scheduled finish, on that day');
    expect(find.text('When did you finish?'), findsNothing);
  });

  testWidgets('a day without anything, and the arrows either side of the date stop at today', (tester) async {
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'Week');
    await tap(tester, 'Mon 19');

    await tester.tap(find.byTooltip('Previous day'));
    await settle(tester);
    await tester.tap(find.byTooltip('Previous day'));
    await settle(tester);
    expect(find.text('Saturday 17 October'), findsOneWidget);
    expect(find.text('No work was planned and nothing was registered.'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('Next day'));
      await settle(tester);
    }
    expect(find.text('Thursday 22 October'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull, reason: 'no future days');
  });

  testWidgets('a swipe changes the day too, and also stops at today', (tester) async {
    await startApp(tester);
    await tap(tester, 'Period');
    await view(tester, 'Week');
    await tap(tester, 'Wed 21');
    expect(find.text('Wednesday 21 October'), findsOneWidget);

    await tester.fling(find.byType(SingleChildScrollView).last, const Offset(300, 0), 1000);
    await settle(tester);
    expect(find.text('Tuesday 20 October'), findsOneWidget, reason: 'swiping right: the day before');

    for (var i = 0; i < 3; i++) {
      await tester.fling(find.byType(SingleChildScrollView).last, const Offset(-300, 0), 1000);
      await settle(tester);
    }
    expect(find.text('Thursday 22 October'), findsOneWidget, reason: 'no swiping past today');
  });

  testWidgets('Period fits a small phone (320 × 568) without overflowing', (tester) async {
    completeTuesday();
    missingFinishYesterday();
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EmployeeApp(services: h.services));
    await settle(tester);
    await tap(tester, 'Period');
    for (final v in ['Week', 'Month', 'Day']) {
      await view(tester, v);
    }
    await view(tester, 'Week');
    await tap(tester, 'Wed 21');
    await tap(tester, 'Add your finish time');
    expect(find.text('When did you finish?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
