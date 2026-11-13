import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:employee_mobile/src/device/device_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

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

  testWidgets('Start work reloads the current project, so the default shows at once', (tester) async {
    await startApp(tester);
    final before = h.server.requestsTo('/me/activity').length;

    await tap(tester, 'Start work');

    expect(h.server.requestsTo('/me/activity').length, greaterThan(before));
  });

  testWidgets('not started: the schedule; Start work → working; Finish work → complete with the registered time', (tester) async {
    await startApp(tester);
    expect(find.text('Tap Start work when you begin.'), findsOneWidget);
    expect(find.text('Planned today'), findsOneWidget);
    expect(find.text('08:00 – 16:30'), findsOneWidget);
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
    expect(find.text('You’re working'), findsOneWidget);
    expect(find.text('Since 09:00 · Started in the app'), findsOneWidget);
    expect(find.text('Registered today'), findsOneWidget);
    expect(find.text('Planned finish 16:30'), findsOneWidget);
    expect(find.text('Started'), findsOneWidget, reason: 'the timeline');
    expect(find.text('In the app'), findsOneWidget);

    now = DateTime(2026, 10, 22, 11, 14);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('2h 14m'), findsOneWidget, reason: 'registered today moves on');

    now = DateTime(2026, 10, 22, 17, 7);
    await tap(tester, 'Finish work');
    expect(h.server.registrations.last['boundary'], 'finish');
    expect(find.text('Your day is done'), findsOneWidget);
    expect(find.text('7h 37m'), findsNWidgets(2), reason: '09:00–17:07 minus the 30 min break, from the server; also the week so far');
    expect(find.text('09:00 – 17:07'), findsOneWidget);
    expect(find.text('Planned 8h 00m · 30 min break'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Finish work'), findsNothing);
  });

  testWidgets('registered today deducts the break once it has passed, as the finished day does', (tester) async {
    await startApp(tester);
    await tap(tester, 'Start work');

    now = DateTime(2026, 10, 22, 12, 15);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('3h 00m'), findsOneWidget, reason: '09:00–12:15 minus the 15 min of the break passed so far');

    now = DateTime(2026, 10, 22, 13);
    await tester.pump(const Duration(seconds: 31));
    expect(find.text('3h 30m'), findsOneWidget, reason: 'the whole 30 min break');
  });

  testWidgets('back in the foreground, the day is loaded again (e.g. after HR approved)', (tester) async {
    await startApp(tester);
    final before = h.server.requestsTo('/me/today').length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);

    expect(h.server.requestsTo('/me/today').length, before + 1);
  });

  testWidgets('forgot to start: a reason is required, Use scheduled time, then it waits for HR', (tester) async {
    now = DateTime(2026, 10, 22, 10);
    await startApp(tester);

    await tap(tester, 'Forgot to start? Enter when you arrived');
    expect(find.text('When did you arrive?'), findsOneWidget);
    expect(find.text('You forgot to start. Enter when you arrived.'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm start time');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull, reason: 'no reason yet');

    await tap(tester, 'Use it');
    expect([for (final f in tester.widgetList<TextField>(find.byType(TextField)).take(2)) f.controller!.text], ['08', '00']);
    await tester.enterText(find.byType(TextField).at(2), 'Forgot to register when I came in.');
    await tester.pump();
    await tap(tester, 'Confirm start time');

    expect(h.server.registrations.single, containsPair('entry', 'corrected'));
    expect(h.server.registrations.single['reason'], 'Forgot to register when I came in.');
    expect(h.server.registrations.single['at'], DateTime(2026, 10, 22, 8).toUtc().toIso8601String());
    expect(find.text('You’re working'), findsOneWidget);
    expect(find.text('Since 08:00 · Your start time waits for HR'), findsOneWidget);
    expect(find.text('Waiting for HR'), findsOneWidget, reason: 'on the start in the timeline');
  });

  testWidgets('progress toward the planned day sits under the total (Figma 1606:2)', (tester) async {
    await startApp(tester);
    await tap(tester, 'Start work');
    expect(find.text('of 8h 00m'), findsOneWidget, reason: '08:00–16:30 minus the 30 min break');
    final line = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(line.value, inInclusiveRange(0, 1));
  });

  testWidgets('This week sits at the bottom of Home and opens Period on the week; the tab opens it on the day', (tester) async {
    h.server.pastDays['2026-10-20'] = (
      {'employeeId': 1, 'employeeCode': '', 'date': '2026-10-20', 'status': 'complete', 'events': <Object?>[]},
      450,
    );
    await startApp(tester);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('7h 30m'), findsOneWidget, reason: 'the same number as Period’s week');
    expect(find.text('of 40h'), findsOneWidget);

    await tap(tester, 'This week');
    expect(find.text('19–25 October 2026'), findsOneWidget, reason: 'Period on the week');

    await tap(tester, 'Home');
    await tap(tester, 'Period');
    expect(find.text('Thursday 22 October'), findsOneWidget, reason: 'the tab opens Period on the day');
  });

  testWidgets('a refresh that fails keeps the day and says so; Try again loads it again (Figma 1602:2)', (tester) async {
    await startApp(tester);
    await tap(tester, 'Start work');
    expect(find.text('You’re working'), findsOneWidget);

    h.server.dropNext.add('/me/today');
    await tester.fling(find.byType(SingleChildScrollView).first, const Offset(0, 400), 1000);
    await settle(tester);
    expect(find.text('You’re working'), findsOneWidget, reason: 'the day already loaded stays');
    expect(find.text('Couldn’t refresh ·'), findsOneWidget);

    await tap(tester, 'Try again');
    expect(find.text('Couldn’t refresh ·'), findsNothing);
    expect(find.text('You’re working'), findsOneWidget);
  });

  testWidgets('a start waiting for HR counts from its rounded time, as a normal start does', (tester) async {
    // Entered 06:04; rounded up to the next quarter it counts from 06:15 once
    // approved (the server's preview).
    h.server.registrations.add({
      'boundary': 'start',
      'entry': 'corrected',
      'at': DateTime(2026, 10, 22, 6, 4).toUtc().toIso8601String(),
      'reason': 'Forgot',
    });
    h.server.pendingRounded = DateTime(2026, 10, 22, 6, 15);
    h.server.firstDay = false;
    now = DateTime(2026, 10, 22, 9, 30);
    await startApp(tester);

    expect(find.text('Since 06:04 · Your start time waits for HR'), findsOneWidget, reason: 'shown as entered');
    expect(find.text('3h 15m'), findsOneWidget, reason: 'counted from 06:15, as it will count, not 3h 26m from 06:04');
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
    expect(find.text('Your day is done'), findsOneWidget);
    expect(find.text('Waiting for HR'), findsNWidgets(2), reason: 'instead of the total, and on the finish');
    expect(find.text('Your total shows once HR approves the correction.'), findsOneWidget);
    expect(find.text('09:00 – 16:41'), findsOneWidget);
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

  testWidgets('a correction the server refuses: the red note, and confirming again', (tester) async {
    await startApp(tester);
    await tap(tester, 'Forgot to start? Enter when you arrived');
    await tester.enterText(find.byType(TextField).at(2), 'Forgot');
    await tester.pump();
    h.server.refuseNextRegistration = 'validation_failed';
    await tap(tester, 'Confirm start time');

    expect(find.text('Your start time wasn’t saved'), findsOneWidget);
    expect(find.text('This time isn’t possible. Check it and try again.'), findsOneWidget);
    await tap(tester, 'Confirm start time');
    expect(find.text('You’re working'), findsOneWidget);
  });

  testWidgets('Start work without a connection: not saved, nothing shown as started', (tester) async {
    await startApp(tester);
    h.server.dropNext.add('/me/time-registrations');
    await tap(tester, 'Start work');

    expect(find.text('Your start time wasn’t saved'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    expect(find.text('You’re working'), findsNothing);
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
    expect(find.text('Registration method'), findsOneWidget);
  });

  testWidgets('working: the project with Switch, and the day as one timeline (Figma 1585:2)', (tester) async {
    final since = DateTime(2026, 10, 22, 9).toUtc();
    const project = MyProject(id: 4, name: 'P-1042 Office refurbishment', isClient: true, placeName: 'Antwerp');
    h.server.activity = MyActivity(
      enabled: true,
      current: CurrentActivity(kind: ActivityKind.clientOnSite, since: since, project: project),
      projects: const [project],
      companies: const [MyCompany(id: 7, name: 'Almeco', isDefault: true)],
      breakdown: const ActivityBreakdown(clientMinutes: 120, transportMinutes: 42, trips: 1, distanceMetres: 36000),
      today: const [
        ActivityEntry(timeLocal: '09:00', kind: ActivityKind.clientOnSite, projectName: 'P-1042 Office refurbishment'),
        ActivityEntry(timeLocal: '10:12', kind: ActivityKind.transport, metres: 36000),
        ActivityEntry(timeLocal: '11:02', kind: ActivityKind.clientOnSite, placeName: 'Cooling towers'),
      ],
    );
    await startApp(tester);
    await tap(tester, 'Start work');

    expect(find.text('P-1042 Office refurbishment'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(
      find.text('Planned finish 16:30 · + 0h 42m travel · 36 km'),
      findsOneWidget,
      reason: 'travel beside the total, never in it (D46)',
    );
    expect(find.text('09:00'), findsOneWidget, reason: 'the start once, not again as its first switch');
    expect(find.text('Transport'), findsOneWidget);
    expect(find.text('36 km'), findsOneWidget);
    expect(find.text('Cooling towers'), findsOneWidget);

    await tap(tester, 'Switch');
    expect(find.text('What are you working on?'), findsOneWidget);
  });

  testWidgets('every Home state fits a small phone (320 × 568) without overflowing', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EmployeeApp(services: h.services));
    await settle(tester);
    expect(find.text('Planned today'), findsOneWidget);

    await tap(tester, 'Start work');
    expect(find.text('Registered today'), findsOneWidget);
    await tap(tester, 'Finished earlier? Enter the time');
    expect(find.text('When did you finish?'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    now = DateTime(2026, 10, 22, 17);
    await tap(tester, 'Finish work');
    expect(find.text('Your day is done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('what Home offers follows the registration method (product owner, 2026-11-12)', () {
    testWidgets('Automatic: no button, Jitan starts the day; "Start work now" still can', (tester) async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.automatic);
      await startApp(tester);

      expect(find.text('Jitan starts your day when you arrive at work.'), findsOneWidget);
      expect(find.byType(JitanMobileButton), findsNothing);
      await tap(tester, 'Start work now');
      expect(h.server.registrations.single, containsPair('entry', 'now'));

      expect(find.text('You’re working'), findsOneWidget);
      expect(find.byType(JitanMobileButton), findsNothing);
      expect(find.text('Finish work now'), findsOneWidget);
    });

    testWidgets('Automatic without location access cannot register: the buttons are back', (tester) async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.automatic);
      h.permissions.backgroundLocationGranted = false;
      await startApp(tester);

      expect(find.text('Tap Start work when you begin.'), findsOneWidget);
      expect(find.widgetWithText(JitanMobileButton, 'Start work'), findsOneWidget);
    });

    testWidgets('QR: "Show my QR" opens the QR tab; the app is the quiet way', (tester) async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.qr);
      await startApp(tester);

      expect(find.text('Scan your QR at a Jitan Terminal when you arrive.'), findsOneWidget);
      expect(find.text('Start in the app instead'), findsOneWidget);
      await tap(tester, 'Show my QR');
      expect(find.text('My QR'), findsOneWidget);
    });

    testWidgets('QR, started in the app: still "Show my QR" to finish, or finish in the app', (tester) async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.qr);
      await startApp(tester);
      await tap(tester, 'Start in the app instead');

      expect(find.widgetWithText(JitanMobileButton, 'Show my QR'), findsOneWidget);
      await tap(tester, 'Finish in the app instead');
      expect(h.server.registrations.last, containsPair('boundary', 'finish'));
      expect(find.text('Your day is done'), findsOneWidget);
    });

    testWidgets('a method changed in Profile shows on Home when coming back', (tester) async {
      await startApp(tester);
      expect(find.widgetWithText(JitanMobileButton, 'Start work'), findsOneWidget);

      await h.services.settings.setRegistrationMethod(RegistrationMethod.qr);
      await tap(tester, 'Profile');
      expect(find.text('QR'), findsNWidgets(2), reason: 'the row says "QR" in short, beside the tab');
      await tap(tester, 'Home');
      expect(find.widgetWithText(JitanMobileButton, 'Show my QR'), findsOneWidget);
    });
  });
}
