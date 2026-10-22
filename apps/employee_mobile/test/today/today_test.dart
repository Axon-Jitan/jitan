import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_jitan_server.dart';

/// Today (Figma 1444:3, 1436:128, 1436:2/43/84, 1436:172, 1436:213; greeting
/// 1452:2), against the fake server's rules (D30, D31, D13).
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

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Future<void> enterTime(WidgetTester tester, String hours, String minutes) async {
    await tester.enterText(find.byType(TextField).at(0), hours);
    await tester.enterText(find.byType(TextField).at(1), minutes);
    await tester.pump();
  }

  for (final (hour, greeting) in [(9, 'Good morning, Disan.'), (14, 'Good afternoon, Disan.'), (19, 'Good evening, Disan.')]) {
    testWidgets('at $hour:00 the greeting is "$greeting"', (tester) async {
      now = DateTime(2026, 10, 22, hour);
      await startApp(tester);
      expect(find.text(greeting), findsOneWidget);
    });
  }

  testWidgets('not started: the schedule; Start work → working; Finish work → complete with the registered time', (tester) async {
    await startApp(tester);
    expect(find.text('Tap Start work when you begin.'), findsOneWidget);
    expect(find.text('YOUR SCHEDULE TODAY'), findsOneWidget);
    expect(find.text('08:00 — 16:30'), findsOneWidget);
    expect(find.text('30 min break'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tap(tester, 'Start work');
    expect(h.server.registrations.single, {
      'boundary': 'start',
      'method': 'manual',
      'entry': 'now',
      'at': DateTime(2026, 10, 22, 9).toUtc().toIso8601String(),
      'reason': null,
    });
    expect(find.text('You’re working.'), findsOneWidget);
    expect(find.text('WORKING NOW'), findsOneWidget);
    expect(find.text('Started 09:00'), findsOneWidget);
    expect(find.text('Started in the app'), findsOneWidget);
    expect(find.text('Scheduled finish'), findsOneWidget);

    now = DateTime(2026, 10, 22, 11, 14);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('2h 14m'), findsOneWidget, reason: 'registered today moves on');

    now = DateTime(2026, 10, 22, 17, 7);
    await tap(tester, 'Finish work');
    expect(h.server.registrations.last['boundary'], 'finish');
    expect(find.text('Your day is complete.'), findsOneWidget);
    expect(find.text('COMPLETE'), findsOneWidget);
    expect(find.text('7h 37m'), findsOneWidget, reason: '09:00–17:07 minus the 30 min break, from the server');
    expect(find.text('09:00 — 17:07'), findsOneWidget);
  });

  testWidgets('forgot to start: a reason is required, Use scheduled time, then it waits for HR', (tester) async {
    now = DateTime(2026, 10, 22, 10);
    await startApp(tester);

    await tap(tester, 'Forgot to start? Enter when you arrived');
    expect(find.text('When did you arrive?'), findsOneWidget);
    expect(find.text('You forgot to start. Enter when you arrived.'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm start time');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'no reason yet');

    await tap(tester, 'Use scheduled time');
    expect([for (final f in tester.widgetList<TextField>(find.byType(TextField)).take(2)) f.controller!.text], ['08', '00']);
    await tester.enterText(find.byType(TextField).at(2), 'Forgot to register when I came in.');
    await tester.pump();
    await tap(tester, 'Confirm start time');

    expect(h.server.registrations.single, containsPair('entry', 'corrected'));
    expect(h.server.registrations.single['reason'], 'Forgot to register when I came in.');
    expect(h.server.registrations.single['at'], DateTime(2026, 10, 22, 8).toUtc().toIso8601String());
    expect(find.text('You’re working.'), findsOneWidget);
    expect(find.text('Waiting for HR approval'), findsOneWidget);
    expect(find.text('Started 08:00'), findsOneWidget);
  });

  testWidgets('finished earlier: the finish correction waits for HR; the day shows WAITING FOR HR and no total', (tester) async {
    await startApp(tester);
    await tap(tester, 'Start work');
    now = DateTime(2026, 10, 22, 18);
    await tester.pump(const Duration(seconds: 31));

    await tap(tester, 'Finished earlier? Enter the time');
    expect(find.text('When did you finish?'), findsOneWidget);
    await enterTime(tester, '16', '41');
    await tester.enterText(find.byType(TextField).at(2), 'Left without registering.');
    await tester.pump();
    await tap(tester, 'Confirm finish time');

    expect(h.server.registrations.last, containsPair('boundary', 'finish'));
    expect(find.text('Your day is complete.'), findsOneWidget);
    expect(find.text('WAITING FOR HR'), findsOneWidget);
    expect(find.text('09:00 — 16:41'), findsOneWidget);
    expect(find.text('registered today'), findsNothing, reason: 'it counts once HR approves');
  });

  testWidgets('a time still to come is refused before sending', (tester) async {
    await startApp(tester);
    await tap(tester, 'Forgot to start? Enter when you arrived');
    await enterTime(tester, '10', '30');
    await tester.enterText(find.byType(TextField).at(2), 'x');
    await tester.pump();
    await tap(tester, 'Confirm start time');

    expect(find.text('This time is still to come.'), findsOneWidget);
    expect(h.server.registrations, isEmpty);
  });

  testWidgets('a correction the server refuses: the red note and Try again', (tester) async {
    await startApp(tester);
    await tap(tester, 'Forgot to start? Enter when you arrived');
    await tester.enterText(find.byType(TextField).at(2), 'Forgot');
    await tester.pump();
    h.server.refuseNextRegistration = 'validation_failed';
    await tap(tester, 'Confirm start time');

    expect(find.text('Your start time wasn’t saved'), findsOneWidget);
    expect(find.text('This time isn’t possible. Check it and try again.'), findsOneWidget);
    await tap(tester, 'Try again');
    expect(find.text('You’re working.'), findsOneWidget);
  });

  testWidgets('Start work without a connection: not saved, nothing shown as started', (tester) async {
    await startApp(tester);
    h.server.dropNext.add('/me/time-registrations');
    await tap(tester, 'Start work');

    expect(find.text('Your start time wasn’t saved'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('You’re working.'), findsNothing);
  });

  testWidgets('the day can not be loaded: Try again', (tester) async {
    h.server.dropNext.add('/me/today');
    await startApp(tester);
    expect(find.text('Your day couldn’t be loaded'), findsOneWidget);

    await tap(tester, 'Try again');
    expect(find.text('Good morning, Disan.'), findsOneWidget);
  });

  testWidgets('no schedule today; Profile opens from the bar', (tester) async {
    h.server
      ..scheduledStart = null
      ..scheduledFinish = null
      ..breakMinutes = null;
    await startApp(tester);
    expect(find.text('No schedule today'), findsOneWidget);

    await tap(tester, 'Profile');
    expect(find.text('Employee code'), findsOneWidget);
  });
}
