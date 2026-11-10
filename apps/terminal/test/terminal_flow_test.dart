import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:terminal/src/flow/terminal_controller.dart';

import 'support/fakes.dart';

void main() {
  Future<Harness> open(WidgetTester tester, {String? token = '1.secret'}) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = Harness(token: token);
    await tester.pumpWidget(h.app());
    await tester.pump();
    await tester.pump();
    return h;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> scan(WidgetTester tester, Harness h, [String code = 'employee-qr']) async {
    h.read!(code);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('connecting', () {
    testWidgets('a new tablet asks to connect, and a good code makes it ready, then the camera', (tester) async {
      final h = await open(tester, token: null);
      expect(find.text('Connect this tablet'), findsOneWidget);
      expect(find.text('New tablet'), findsOneWidget);

      await scan(tester, h, 'pairing-code');

      expect(h.api.pairs.single.deviceName, 'Samsung Tab A9');
      expect(find.text('This tablet is ready'), findsOneWidget);
      expect(h.store.saved, '1.secret');
      expect(h.token, '1.secret');

      await tester.pump(TerminalController.readyFor);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hold your Jitan QR up to the camera'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('an old code says so and the camera stays', (tester) async {
      final h = await open(tester, token: null);
      h.api.failPair = refused(410, ApiErrorCode.qrExpired);

      await scan(tester, h, 'old-code');

      expect(find.text('That code has expired'), findsOneWidget);
      expect(h.store.saved, isNull);
      await leave(tester);
    });

    testWidgets('a tablet HR removed goes back to connecting, and forgets its secret', (tester) async {
      final h = await open(tester);
      h.api.failScan = refused(401, ApiErrorCode.unauthenticated);

      await scan(tester, h);

      expect(find.text('Connect this tablet'), findsOneWidget);
      expect(h.store.saved, isNull);
      expect(h.token, isNull);
      await leave(tester);
    });
  });

  group('scanning', () {
    testWidgets('nothing to tap: the camera is the home screen', (tester) async {
      final h = await open(tester);

      expect(find.text('09:42'), findsOneWidget);
      expect(find.text('Monday 2 November'), findsOneWidget);
      expect(find.text('Almeco Reception'), findsOneWidget);
      expect(h.read, isNotNull);
      expect(find.text('Visiting?'), findsNothing);
      await leave(tester);
    });

    testWidgets('checked in greets by name, shows the project and comes back by itself', (tester) async {
      final h = await open(tester);

      await scan(tester, h);

      expect(find.text('Good morning, Disan'), findsOneWidget);
      expect(find.text('Checked in at 09:42'), findsOneWidget);
      expect(find.text('Cooling towers'), findsOneWidget);
      expect(find.text('On site · Almeco'), findsOneWidget);

      await tester.pump(TerminalController.resultFor);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Disan'), findsNothing, reason: 'a shared tablet doesn’t keep a name up');
      await leave(tester);
    });

    testWidgets('checked out, and the same scan again', (tester) async {
      final h = await open(tester);
      h.api.result = scanResult(TerminalScanOutcome.checkedOut);

      await scan(tester, h);
      expect(find.text('See you tomorrow, Disan'), findsOneWidget);
      expect(find.text('Checked out at 09:42'), findsOneWidget);

      h.controller.backToCamera();
      await tester.pump(const Duration(milliseconds: 300));
      h.api.result = scanResult(TerminalScanOutcome.alreadyCheckedIn);
      h.now = h.now.add(TerminalController.sameCodeFor);

      await scan(tester, h);
      expect(find.text('You’re already checked in'), findsOneWidget);
      expect(find.text('Since 09:42'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a code still in front of the camera isn’t a second scan', (tester) async {
      final h = await open(tester);

      await scan(tester, h);
      h.controller.backToCamera();
      await tester.pump(const Duration(milliseconds: 300));
      await scan(tester, h);

      expect(h.api.scans, hasLength(1));
      await leave(tester);
    });

    testWidgets('a code that isn’t a Jitan QR: said on the camera screen, which stays', (tester) async {
      final h = await open(tester);
      h.api.failScan = refused(400, ApiErrorCode.qrNotRecognised);

      await scan(tester, h, 'a-supermarket-receipt');

      expect(find.text('That didn’t scan'), findsOneWidget);
      await tester.pump(TerminalController.noteFor);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hold your Jitan QR up to the camera'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('an account problem and not being allowed look the same: ask HR', (tester) async {
      for (final code in [ApiErrorCode.employeeUnavailable, ApiErrorCode.scanNotAllowed]) {
        final h = await open(tester);
        h.api.failScan = refused(403, code);

        await scan(tester, h);

        expect(find.text('We can’t register you here'), findsOneWidget);
        await tester.tap(find.text('Back'));
        await tester.pump(const Duration(milliseconds: 300));
        await leave(tester);
      }
    });

    testWidgets('no connection says nothing was registered, and keeps nothing (D42)', (tester) async {
      final h = await open(tester);
      h.api.failScan = const ApiClientException.network('offline');

      await scan(tester, h);

      expect(find.text('Jitan can’t be reached'), findsOneWidget);
      expect(find.text('Nothing was registered. Please try again in a moment.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Hold your Jitan QR up to the camera'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a tablet with no connection at the start still shows the camera', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = Harness(token: '1.secret');
      h.api.failMe = const ApiClientException.network('offline');

      await tester.pumpWidget(h.app());
      await tester.pump();
      await tester.pump();

      expect(find.text('Hold your Jitan QR up to the camera'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('switched off by HR: says so, with no camera', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = Harness(token: '1.secret');
      h.api.info_ = const TerminalInfo(id: 1, name: 'Almeco Reception', canScan: false);

      await tester.pumpWidget(h.app());
      await tester.pump();
      await tester.pump();

      expect(find.text('This terminal is switched off'), findsOneWidget);
      expect(h.read, isNull);
      await leave(tester);
    });
  });

  group('changing project', () {
    Future<Harness> choosing(WidgetTester tester) async {
      final h = await open(tester);
      await scan(tester, h);
      await tester.tap(find.text('Change'));
      await tester.pump(const Duration(milliseconds: 300));
      return h;
    }

    testWidgets('lists their projects and Transport, and stays until they choose', (tester) async {
      final h = await choosing(tester);

      expect(find.text('What are you working on?'), findsOneWidget);
      expect(find.text('Clean the workshop'), findsOneWidget);
      expect(find.text('Internal · Almeco'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);

      await tester.pump(TerminalController.resultFor * 2);
      expect(find.text('What are you working on?'), findsOneWidget);
      expect(h.api.switches, isEmpty);
      await leave(tester);
    });

    testWidgets('a project switches at once and proves who it is for with the QR', (tester) async {
      final h = await choosing(tester);

      await tester.tap(find.text('Clean the workshop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final sent = h.api.switches.single;
      expect((sent.kind, sent.projectId, sent.qrCode), (ActivityKind.internal, 2, 'employee-qr'));
      expect(find.text('Hold your Jitan QR up to the camera'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('Transport has no project', (tester) async {
      final h = await choosing(tester);

      await tester.tap(find.text('Transport'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect((h.api.switches.single.kind, h.api.switches.single.projectId), (ActivityKind.transport, null));
      await leave(tester);
    });

    testWidgets('Keep changes nothing', (tester) async {
      final h = await choosing(tester);

      await tester.tap(find.text('Keep Cooling towers'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(h.api.switches, isEmpty);
      await leave(tester);
    });

    testWidgets('a switch that fails says so and stays', (tester) async {
      final h = await choosing(tester);
      h.api.failSwitch = const ApiClientException.network('offline');

      await tester.tap(find.text('Transport'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('That could not be saved. Try again.'), findsOneWidget);
      await leave(tester);
    });
  });

  group('fits the tablet', () {
    for (final size in [const Size(1024, 768), const Size(1280, 800), const Size(800, 600), const Size(1920, 1200)]) {
      testWidgets('every screen at ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final h = Harness(token: '1.secret');
        await tester.pumpWidget(h.app());
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'home');

        await scan(tester, h);
        expect(tester.takeException(), isNull, reason: 'checked in');

        await tester.tap(find.text('Change'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'choose');
        await leave(tester);

        final connecting = Harness();
        await tester.pumpWidget(connecting.app());
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'connect');
        await leave(tester);
      });
    }
  });
}
