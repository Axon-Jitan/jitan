import 'package:employee_mobile/src/device/device_settings.dart';
import 'package:employee_mobile/src/geofencing/automatic_registration.dart';
import 'package:employee_mobile/src/geofencing/geofence_event_handler.dart';
import 'package:employee_mobile/src/geofencing/location_watcher.dart';
import 'package:employee_mobile/src/geofencing/workplace_presence.dart';
import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:employee_mobile/src/profile/location_permission_screen.dart';
import 'package:employee_mobile/src/profile/registration_method_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_jitan_server.dart';

class _FakeWatcher implements LocationWatcher {
  List<Location>? watched;
  bool stopped = false;

  bool accept = true;

  @override
  Future<bool> watch(List<Location> locations) async {
    watched = locations;
    return accept;
  }

  @override
  Future<void> stop() async => stopped = true;
}

/// Thursday 22 October 2026.
void main() {
  late TestHarness h;
  late DateTime now;
  late WorkplacePresence presence;
  late GeofenceEventHandler handler;

  setUp(() async {
    now = DateTime(2026, 10, 22, 8);
    h = TestHarness(clock: () => now);
    h.server.issuedTokens.add('stored-token');
    h.store.values
      ..['session.token'] = 'stored-token'
      ..['session.expiresAt'] = '2099-01-01T00:00:00.000Z';
    await h.session.restore();
    h.server.firstDay = false;
    presence = WorkplacePresence(h.store);
    handler = GeofenceEventHandler(api: h.services.timeRegistrationsApi, presence: presence, reminder: h.reminder, clock: () => now);
  });

  group('the rules on the phone', () {
    test('arriving: stored after staying, at the moment of entering (D33)', () async {
      await handler.handle(GeofenceChange.entered, 7);
      expect(h.server.registrations, isEmpty, reason: 'driving past is not an arrival');

      now = now.add(const Duration(minutes: 5));
      await handler.handle(GeofenceChange.stayed, 7);

      final sent = h.server.registrations.single;
      expect((sent['boundary'], sent['method'], sent['addressId']), ('start', 'geofence', 7));
      expect(sent['at'], DateTime(2026, 10, 22, 8).toUtc().toIso8601String());
    });

    test('no stayed event: the app opening registers it, at the moment of entering', () async {
      await handler.handle(GeofenceChange.entered, 7);
      now = now.add(const Duration(hours: 1));

      await handler.catchUp();
      await handler.catchUp();

      final sent = h.server.registrations.single;
      expect(sent['at'], DateTime(2026, 10, 22, 8).toUtc().toIso8601String());
    });

    test('told twice that it entered: the first moment counts', () async {
      await handler.handle(GeofenceChange.entered, 7);
      now = now.add(const Duration(minutes: 3));
      await handler.handle(GeofenceChange.entered, 7);
      now = now.add(const Duration(minutes: 3));

      await handler.handle(GeofenceChange.stayed, 7);

      expect(h.server.registrations.single['at'], DateTime(2026, 10, 22, 8).toUtc().toIso8601String());
    });

    test('the app opening too soon registers nothing yet', () async {
      await handler.handle(GeofenceChange.entered, 7);
      now = now.add(const Duration(minutes: 4));

      await handler.catchUp();

      expect(h.server.registrations, isEmpty);
      expect(await presence.lastEntered(), isNotNull);
    });

    test('no stayed event: leaving after five minutes registers the start, then away', () async {
      await handler.handle(GeofenceChange.entered, 7);
      now = DateTime(2026, 10, 22, 12);

      await handler.handle(GeofenceChange.left, 7);

      expect(h.server.registrations.single['boundary'], 'start');
      expect(await presence.away(), isNotNull);
    });

    test('entering and leaving at once registers nothing', () async {
      await handler.handle(GeofenceChange.entered, 7);
      await handler.handle(GeofenceChange.left, 7);

      expect(h.server.registrations, isEmpty);
      expect(await presence.away(), isNull, reason: 'no day is running');
    });

    test('leaving during the day is remembered, not registered (D32)', () async {
      await presence.saveNames([_almeco]);
      await handler.handle(GeofenceChange.entered, 7);
      now = now.add(const Duration(minutes: 5));
      await handler.handle(GeofenceChange.stayed, 7);

      now = DateTime(2026, 10, 22, 12, 3);
      await handler.handle(GeofenceChange.left, 7);

      final away = await presence.away();
      expect((away?.name, away?.leftAt.toLocal()), ('Almeco office', now));
      expect(h.server.registrations, hasLength(1), reason: 'only the start');
    });

    test('back at any recognised location: no longer away, and no reminder', () async {
      await presence.left(7, now);
      h.reminder.scheduled = now;

      await handler.handle(GeofenceChange.entered, 8);

      expect(await presence.away(), isNull);
      expect(h.reminder.scheduled, isNull);
    });

    test('leaving during the day sets the reminder for an hour later (D32)', () async {
      h.server.registrations.add({'boundary': 'start', 'entry': 'now', 'at': now.toUtc().toIso8601String()});
      now = DateTime(2026, 10, 22, 12, 3);

      await handler.handle(GeofenceChange.left, 7);

      expect(h.reminder.scheduled, DateTime(2026, 10, 22, 13, 3));
    });
  });

  group('turning detection on', () {
    late _FakeWatcher watcher;
    late AutomaticRegistration automatic;

    setUp(() {
      watcher = _FakeWatcher();
      h.server.locations = [_almeco];
      automatic = AutomaticRegistration(
        settings: h.services.settings,
        permissions: h.permissions,
        locations: h.services.locationsApi,
        watcher: watcher,
        presence: presence,
        events: handler,
      );
    });

    test('on Automatic with permission: the recognised locations are watched', () async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.automatic);

      await automatic.start();

      expect(watcher.watched?.single.name, 'Almeco office');
      expect(await presence.nameOf(7), 'Almeco office');
    });

    test('the phone refuses: remembered for Location permission; accepted later: forgotten', () async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.automatic);
      watcher.accept = false;
      await automatic.start();
      expect(await presence.geofencesRefused(), true);

      watcher.accept = true;
      await automatic.start();
      expect(await presence.geofencesRefused(), false);
    });

    test('on QR / manual: nothing is watched', () async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.manual);

      await automatic.start();

      expect((watcher.watched, watcher.stopped), (null, true));
    });

    test('without background permission: nothing is watched', () async {
      await h.services.settings.setRegistrationMethod(RegistrationMethod.automatic);
      h.permissions.backgroundLocationGranted = false;

      await automatic.start();

      expect(watcher.watched, isNull);
    });
  });

  group('Profile / Registration method (Figma 94:2)', () {
    late _FakeWatcher watcher;
    late var changes = 0;

    Future<void> open(WidgetTester tester) async {
      watcher = _FakeWatcher();
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await h.services.settings.setRegistrationMethod(RegistrationMethod.manual);
      await tester.pumpWidget(TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.light(),
          home: RegistrationMethodScreen(
            settings: h.services.settings,
            permissions: h.permissions,
            onChanged: () async => changes++,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(watcher.watched, isNull);
    }

    JitanMobileButton save(WidgetTester tester) => tester.widget(find.byType(JitanMobileButton));

    testWidgets('Save stays off until the method changes, then asks for location', (tester) async {
      changes = 0;
      await open(tester);
      expect(find.text('Current'), findsOneWidget);
      expect(save(tester).onPressed, isNull);

      await tester.tap(find.text('Automatic registration'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(await h.services.settings.registrationMethod(), RegistrationMethod.automatic);
      expect(h.permissions.asked, ['location', 'background location']);
      expect(changes, 1);
    });

    testWidgets('location refused: the method stays and the screen says why', (tester) async {
      changes = 0;
      await open(tester);
      h.permissions.backgroundLocationGranted = false;

      await tester.tap(find.text('Automatic registration'));
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(await h.services.settings.registrationMethod(), RegistrationMethod.manual);
      expect(find.text('Automatic registration requires location permission.'), findsOneWidget);
      expect(changes, 0);
    });
  });

  group('We need one answer (Figma 19:76)', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> leftAnHourAgo(WidgetTester tester) async {
      h.server.registrations.add({'boundary': 'start', 'entry': 'now', 'at': DateTime(2026, 10, 22, 8).toUtc().toIso8601String()});
      await presence.saveNames([_almeco]);
      await presence.left(7, DateTime(2026, 10, 22, 12, 3));
      now = DateTime(2026, 10, 22, 13, 3);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(EmployeeApp(services: h.services));
      await settle(tester);
    }

    Map<String, Object?> sent(int i) => h.server.registrations[i];
    final leftUtc = DateTime(2026, 10, 22, 12, 3).toUtc().toIso8601String();

    testWidgets('fifty-nine minutes: not yet', (tester) async {
      h.server.registrations.add({'boundary': 'start', 'entry': 'now', 'at': DateTime(2026, 10, 22, 8).toUtc().toIso8601String()});
      await presence.left(7, DateTime(2026, 10, 22, 12, 3));
      now = DateTime(2026, 10, 22, 13, 2);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(EmployeeApp(services: h.services));
      await settle(tester);

      expect(find.text('We need one answer.'), findsNothing);
      expect(find.text('You’re temporarily away.'), findsOneWidget);
    });

    testWidgets('an hour away: the four answers, where and when they left', (tester) async {
      await leftAnHourAgo(tester);

      expect(find.text('We need one answer.'), findsOneWidget);
      expect(find.text('You left Almeco office at 12:03 and haven’t reached another work location.'), findsOneWidget);
      for (final answer in ['Finished work', 'Break / personal', 'Travelling for work', 'Other']) {
        expect(find.text(answer), findsOneWidget);
      }
    });

    testWidgets('Finished work: a finish at the time they left', (tester) async {
      await leftAnHourAgo(tester);

      await tester.tap(find.text('Finished work'));
      await settle(tester);

      expect((sent(1)['boundary'], sent(1)['method'], sent(1)['at'], sent(1)['addressId']), ('finish', 'geofence', leftUtc, 7));
      expect(await presence.away(), isNull);
      expect(find.text('Your day is complete.'), findsOneWidget);
    });

    testWidgets('Break / personal: the finish is stored and they stay away, unasked', (tester) async {
      await leftAnHourAgo(tester);

      await tester.tap(find.text('Break / personal'));
      await settle(tester);

      expect((sent(1)['boundary'], sent(1)['at']), ('finish', leftUtc));
      expect(find.text('You’re temporarily away.'), findsOneWidget);
      expect((await presence.away())?.onBreak, true);
    });

    testWidgets('Travelling for work: their own time and reason go to HR', (tester) async {
      await leftAnHourAgo(tester);

      await tester.tap(find.text('Travelling for work'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Drove to the client');
      await tester.pump();
      await tester.tap(find.byType(JitanMobileButton).last);
      await settle(tester);

      expect((sent(1)['boundary'], sent(1)['entry']), ('finish', 'now'));
      expect((sent(2)['boundary'], sent(2)['entry'], sent(2)['reason']), ('finish', 'corrected', 'Drove to the client'));
      expect(await presence.away(), isNull);
    });
  });

  group('Profile / Location permission (Figma 94:23)', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.light(),
          home: LocationPermissionScreen(permissions: h.permissions, presence: presence),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('all allowed: working, and what location is used for', (tester) async {
      await open(tester);

      expect(find.text('ALLOWED'), findsOneWidget);
      expect(find.text('Automatic registration is working on this device.'), findsOneWidget);
      expect(find.text('No live tracking'), findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
    });

    testWidgets('not allowed: says so and opens the phone settings', (tester) async {
      h.permissions
        ..grantLocation = false
        ..backgroundLocationGranted = false;
      await open(tester);

      expect(find.text('NOT ALLOWED'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.text('Open phone settings'));
      expect(h.permissions.asked, contains('settings'));
    });

    testWidgets('the phone refused the geofences: names the setting', (tester) async {
      await presence.setGeofencesRefused(true);
      await open(tester);

      expect(find.text('CHECK SETTINGS'), findsOneWidget);
      expect(find.text('Turn on Location Accuracy in your phone’s location settings.'), findsOneWidget);
    });
  });

  group('Temporarily away (Figma 19:52)', () {
    Future<void> startApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(EmployeeApp(services: h.services));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('while the day runs: how long, since when, and no action needed', (tester) async {
      h.server.registrations.add({'boundary': 'start', 'entry': 'now', 'at': DateTime(2026, 10, 22, 8).toUtc().toIso8601String()});
      await presence.saveNames([_almeco]);
      await presence.left(7, DateTime(2026, 10, 22, 12, 3));
      now = DateTime(2026, 10, 22, 12, 21);

      await startApp(tester);

      expect(find.text('You’re temporarily away.'), findsOneWidget);
      expect(find.text('You left Almeco office recently. Your workday is still open.'), findsOneWidget);
      expect(find.text('AWAY'), findsOneWidget);
      expect(find.text('18 min'), findsOneWidget);
      expect(find.text('Left at 12:03'), findsOneWidget);
      expect(find.text('Finish work'), findsNothing);
    });

    testWidgets('a day that is not running is never shown as away', (tester) async {
      await presence.left(7, DateTime(2026, 10, 22, 7));

      await startApp(tester);

      expect(find.text('You’re temporarily away.'), findsNothing);
      expect(await presence.away(), isNull, reason: 'cleared');
    });
  });
}

const _almeco = Location(
  id: 7,
  name: 'Almeco office',
  street: 'Rue du Progrès',
  point: GeoPoint(latitude: 50.7, longitude: 3.2),
  radiusMeters: 50,
  isActive: true,
);
