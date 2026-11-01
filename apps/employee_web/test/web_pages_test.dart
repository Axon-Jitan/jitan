import 'package:employee_web/src/home/home_screen.dart';
import 'package:employee_web/src/period/period_screen.dart';
import 'package:employee_web/src/profile/profile_screen.dart';
import 'package:employee_web/src/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'support/harness.dart';

void main() {
  late Harness h;

  setUp(() async {
    h = Harness();
    await h.signedIn();
  });

  void working() {
    final started = DateTime(2026, 11, 2, 8).toUtc();
    h.server.today = MyDay(
      date: DateTime.utc(2026, 11, 2),
      firstDay: false,
      scheduledStart: '08:00',
      scheduledFinish: '16:30',
      breakMinutes: 30,
      day: record(date: DateTime.utc(2026, 11, 2), start: time('08:00', started)),
    );
    h.server.activity = MyActivity(
      enabled: true,
      projects: const [towers, workshop, warehouse],
      companies: const [almeco],
      current: CurrentActivity(kind: ActivityKind.clientOnSite, since: started, project: towers),
      today: const [
        ActivityEntry(timeLocal: '08:00', kind: ActivityKind.work, placeName: 'Almeco office'),
        ActivityEntry(timeLocal: '10:12', kind: ActivityKind.transport, placeName: 'Cooling towers', metres: 36400),
        ActivityEntry(timeLocal: '11:02', kind: ActivityKind.clientOnSite, projectName: 'Cooling towers'),
      ],
    );
  }

  Widget home() => HomeScreen(services: h.services, clock: () => h.now);

  group('Home', () {
    testWidgets('not started: the plan, nothing to switch, and My QR', (tester) async {
      await h.show(tester, home());

      expect(find.text('Good afternoon'), findsOneWidget);
      expect(find.text('08:00 – 16:30'), findsOneWidget);
      expect(find.text('0h'), findsOneWidget);
      expect(find.text('Switch activity'), findsNothing);
      expect(find.text('My QR'), findsWidgets);
      expect(find.text('Nothing registered yet today.'), findsOneWidget);
    });

    testWidgets('working: the running total, the project and the day as a list', (tester) async {
      working();
      await h.show(tester, home());

      expect(find.text('You’re working'), findsOneWidget);
      expect(find.text('Since 08:00 at Almeco office'), findsOneWidget);
      expect(find.text('4h 18m'), findsOneWidget);
      expect(find.text('Office refurbishment'), findsOneWidget);
      expect(find.text('Started'), findsOneWidget);
      expect(find.text('To Cooling towers · 36 km'), findsOneWidget);
    });

    testWidgets('no project: a place for My QR, not an empty card', (tester) async {
      working();
      h.server.activity = const MyActivity(enabled: true, projects: [], companies: [almeco]);
      await h.show(tester, home());

      expect(find.text('Scanning at a terminal?'), findsOneWidget);
    });

    testWidgets('finished: the server’s hours', (tester) async {
      final at = DateTime(2026, 11, 2, 8).toUtc();
      h.server.today = MyDay(
        date: DateTime.utc(2026, 11, 2),
        firstDay: false,
        registeredMinutes: 468,
        scheduledStart: '08:00',
        scheduledFinish: '16:30',
        breakMinutes: 30,
        day: record(date: DateTime.utc(2026, 11, 2), status: TimeRecordStatus.complete, start: time('08:00', at), finish: time('16:30', at)),
      );
      await h.show(tester, home());

      expect(find.text('Your day is done'), findsOneWidget);
      expect(find.text('7h 48m'), findsOneWidget);
      expect(find.text('Planned 8h'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Switch activity'), findsNothing);
    });

    testWidgets('no connection says so, and Try again works', (tester) async {
      h.server.offline = true;
      await h.show(tester, home());
      expect(find.text('Jitan can’t be reached'), findsOneWidget);

      h.server.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Good afternoon'), findsOneWidget);
    });

    testWidgets('My QR is only ever a picture', (tester) async {
      await h.show(tester, home());
      await tester.tap(find.widgetWithText(JitanSecondaryButton, 'My QR'));
      await tester.pumpAndSettle();

      expect(find.byType(JitanQrCode), findsOneWidget);
      expect(find.text('employee-qr'), findsNothing);
    });

    testWidgets('switching: a tap saves it, with the project’s kind', (tester) async {
      working();
      await h.show(tester, home());
      await tester.tap(find.text('Switch activity'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clean the workshop'));
      await tester.pumpAndSettle();

      final sent = h.server.posts['/me/activity']!.single;
      expect((sent['kind'], sent['projectId']), ('internal', 2));
    });

    testWidgets('Company shows only for someone in several', (tester) async {
      working();
      await h.show(tester, home());
      await tester.tap(find.text('Switch activity'));
      await tester.pumpAndSettle();
      expect(find.text('Company'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      h.server.activity = MyActivity(
        enabled: true,
        projects: const [towers],
        companies: const [almeco, pca],
        current: h.server.activity.current,
      );
      await tester.pumpWidget(const SizedBox());
      await h.show(tester, home());
      await tester.tap(find.text('Switch activity'));
      await tester.pumpAndSettle();
      expect(find.text('Company'), findsOneWidget);
    });
  });

  group('Period', () {
    Widget period() => PeriodScreen(services: h.services, clock: () => DateTime(2026, 11, 6, 18));

    MyPeriodDay missingFinish() => MyPeriodDay(
      date: DateTime.utc(2026, 11, 4),
      scheduledStart: '08:00',
      scheduledFinish: '16:30',
      plannedMinutes: 480,
      day: record(
        date: DateTime.utc(2026, 11, 4),
        status: TimeRecordStatus.missingFinish,
        start: time('08:00', DateTime(2026, 11, 4, 8).toUtc()),
      ),
    );

    testWidgets('an empty month says so, and next is closed in this month', (tester) async {
      await h.show(tester, period());

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('Nothing registered this month.'), findsOneWidget);
      expect(find.text('0 days'), findsOneWidget);
      final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(next.onPressed, isNull);
    });

    testWidgets('a missing finish counts as to fix, and goes to HR with a reason', (tester) async {
      h.server.days = [missingFinish()];
      await h.show(tester, period());

      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('Finish missing'), findsOneWidget);

      await tester.tap(find.text('Wed 4 November'));
      await tester.pumpAndSettle();
      expect(find.text('Your finish time is missing'), findsOneWidget);

      await tester.tap(find.text('Add finish time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send to HR'));
      await tester.pumpAndSettle();
      expect(find.text('Write the time like 16:30.'), findsOneWidget);
      expect(find.text('Say why it is missing.'), findsOneWidget);
      expect(h.server.posts['/me/time-registrations'], isNull);

      await tester.enterText(find.byType(TextField).at(0), '16:30');
      await tester.enterText(find.byType(TextField).at(1), 'I forgot to check out');
      await tester.tap(find.text('Send to HR'));
      await tester.pumpAndSettle();

      final sent = h.server.posts['/me/time-registrations']!.single;
      expect((sent['boundary'], sent['entry'], sent['method'], sent['reason']), ('finish', 'corrected', 'manual', 'I forgot to check out'));
      expect(find.text('Sent to HR'), findsOneWidget);
      expect(find.text('Your finish time counts once HR has checked it.'), findsOneWidget);
    });

    testWidgets('a time still to come stays here', (tester) async {
      h.server.days = [
        MyPeriodDay(
          date: DateTime.utc(2026, 11, 6),
          day: record(date: DateTime.utc(2026, 11, 6), status: TimeRecordStatus.missingFinish, start: time('08:00', DateTime(2026, 11, 6, 8).toUtc())),
        ),
      ];
      await h.show(tester, period());
      await tester.tap(find.text('Fri 6 November'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add finish time'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '23:00');
      await tester.enterText(find.byType(TextField).at(1), 'x');
      await tester.tap(find.text('Send to HR'));
      await tester.pumpAndSettle();

      expect(find.text('This time is still to come.'), findsOneWidget);
    });

    testWidgets('a complete day has nothing to do', (tester) async {
      h.server.days = [
        MyPeriodDay(
          date: DateTime.utc(2026, 11, 3),
          registeredMinutes: 492,
          day: record(
            date: DateTime.utc(2026, 11, 3),
            status: TimeRecordStatus.complete,
            start: time('08:00', DateTime(2026, 11, 3, 8).toUtc()),
            finish: time('16:30', DateTime(2026, 11, 3, 16, 30).toUtc()),
          ),
        ),
      ];
      await h.show(tester, period());
      await tester.tap(find.text('Tue 3 November'));
      await tester.pumpAndSettle();

      expect(find.text('Add finish time'), findsNothing);
      expect(find.text('Add start time'), findsNothing);
    });
  });

  group('Projects', () {
    testWidgets('current and earlier, and a project’s details', (tester) async {
      await h.show(tester, ProjectsScreen(services: h.services));

      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);
      expect(find.text('Completed · Almeco'), findsOneWidget);

      await tester.tap(find.text('Office refurbishment'));
      await tester.pumpAndSettle();

      expect(find.text('PRJ-001'), findsOneWidget);
      expect(find.text('From 19 October 2026'), findsOneWidget);
    });

    testWidgets('none yet says so', (tester) async {
      h.server.activity = const MyActivity(enabled: false, projects: [], companies: []);
      await h.show(tester, ProjectsScreen(services: h.services));

      expect(find.text('You’re not on a project yet.'), findsOneWidget);
    });
  });

  group('Profile', () {
    Widget profile() => ProfileScreen(services: h.services, onLanguageChanged: () {});

    testWidgets('only what works in a browser', (tester) async {
      await h.show(tester, profile());

      expect(find.text('Disan Ssebowa · SBW'), findsOneWidget);
      expect(find.text('Almeco'), findsOneWidget);
      for (final gone in ['Registration method', 'Notifications', 'Privacy', 'Trusted device']) {
        expect(find.text(gone), findsNothing);
      }
    });

    testWidgets('changing the password keeps the person signed in', (tester) async {
      await h.show(tester, profile());
      await tester.tap(find.text('Password'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'old-password');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), 'a-new-password');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(h.server.posts['/me/password'], hasLength(1));
      expect(find.text('Change password'), findsNothing);
      expect(h.session.token, 'token');
    });

    testWidgets('a wrong current password says so', (tester) async {
      h.server.refusePassword = ApiErrorCode.invalidCredentials;
      await h.show(tester, profile());
      await tester.tap(find.text('Password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'wrong');
      await tester.enterText(find.byType(TextField).at(1), 'a-new-password');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('That’s not your current password.'), findsOneWidget);
    });

    testWidgets('Sign out forgets the session', (tester) async {
      await h.show(tester, profile());
      await tester.tap(find.text('Sign out'));
      await tester.pump();

      expect(h.session.token, isNull);
      expect(h.store.values.containsKey('jitan.employee.token'), isFalse);
    });
  });

  group('fits every width', () {
    for (final width in [390.0, 820.0, 1440.0, 2400.0]) {
      testWidgets('every page at $width px', (tester) async {
        working();
        h.server.days = [
          MyPeriodDay(
            date: DateTime.utc(2026, 11, 2),
            day: record(date: DateTime.utc(2026, 11, 2), status: TimeRecordStatus.missingFinish, start: time('08:00', DateTime(2026, 11, 2, 8).toUtc())),
          ),
        ];
        final size = Size(width, 900);
        for (final page in <Widget>[
          home(),
          PeriodScreen(services: h.services, clock: () => DateTime(2026, 11, 6, 18)),
          ProjectsScreen(services: h.services),
          ProfileScreen(services: h.services, onLanguageChanged: () {}),
        ]) {
          await tester.pumpWidget(const SizedBox());
          await h.show(tester, page, size: size);
          expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
        }
        await tester.pumpWidget(const SizedBox());
        await h.show(tester, home(), size: size);
        await tester.tap(find.text('Switch activity'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Switch activity');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(JitanSecondaryButton, 'My QR'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'My QR');
      });
    }
  });
}
