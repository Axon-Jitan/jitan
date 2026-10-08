import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_jitan_server.dart';

void main() {
  late TestHarness h;

  setUp(() => h = TestHarness());

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 logical, like the Figma frames
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EmployeeApp(services: h.services));
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle(tester);
  }

  Future<void> onboardUpToPassword(WidgetTester tester) async {
    await startApp(tester);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan onboarding QR');
    expect(find.text('Is this you?'), findsOneWidget);
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    await tapText(tester, 'Yes, this is me');
    expect(find.text('Automatic registration'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('Finish your setup.'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('Choose your language'), findsOneWidget);
    await tapText(tester, 'Continue');
    expect(find.text('Set your password'), findsOneWidget);
    expect(find.text('7 of 8'), findsOneWidget);
  }

  Future<void> enterPasswords(WidgetTester tester, String password, String confirmation) async {
    await tester.enterText(find.byType(TextField).at(0), password);
    await tester.enterText(find.byType(TextField).at(1), confirmation);
    await tapText(tester, 'Continue');
  }

  testWidgets('scan → confirm → method → permissions → language → password → Ready → Home, no sign-in', (
    tester,
  ) async {
    await onboardUpToPassword(tester);
    expect(find.text('Set this later'), findsNothing, reason: 'the password is mandatory');

    await enterPasswords(tester, 'correct horse battery', 'correct horse battery');
    expect(find.text('You’re ready.'), findsOneWidget);
    expect(h.store.values['session.token'], h.server.issuedTokens.single);

    await tapText(tester, 'Start Jitan');
    expect(find.text('Hello, Disan'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'no second sign-in screen');
  });

  testWidgets('a mismatched confirmation shows the Figma message and sends nothing', (tester) async {
    await onboardUpToPassword(tester);

    await enterPasswords(tester, 'correct horse battery', 'correct horse batterz');

    expect(find.text('Passwords don’t match.'), findsOneWidget);
    expect(h.server.requestsTo('/onboarding/complete'), isEmpty);
    final first = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(first.controller!.text, 'correct horse battery', reason: 'only the confirmation needs fixing');

    await tester.enterText(find.byType(TextField).at(1), 'correct horse battery');
    await tapText(tester, 'Continue');
    expect(find.text('You’re ready.'), findsOneWidget);
  });

  testWidgets('a password the server refuses is an inline field error, not a full-screen error', (tester) async {
    await onboardUpToPassword(tester);
    h.server.rejectPassword = true;

    await enterPasswords(tester, 'correct horse battery', 'correct horse battery');

    expect(find.text('This password can’t be used. Choose another one.'), findsOneWidget);
    expect(find.text('Set your password'), findsOneWidget);
  });

  testWidgets('06B Language: every database language, own name + translated name; the choice applies at once', (
    tester,
  ) async {
    await startApp(tester);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan onboarding QR');
    await tapText(tester, 'Yes, this is me');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');

    for (final (name, translated) in [
      ('English', 'English'),
      ('Nederlands', 'Dutch'),
      ('Français', 'French'),
      ('Deutsch', 'German'),
    ]) {
      expect(find.text(name), findsWidgets);
      expect(find.text(translated), findsWidgets);
    }

    await tapText(tester, 'Nederlands');
    expect(find.text('Frans'), findsOneWidget, reason: 'translated names follow the chosen language');
    await tapText(tester, 'Continue');

    expect(find.text('Stel je wachtwoord in'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget, reason: 'untranslated keys fall back to English');
  });

  testWidgets('an already activated QR shows the error and never restarts onboarding', (tester) async {
    h.server.password = 'set earlier';
    await startApp(tester);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan onboarding QR');

    expect(find.text('Account already activated'), findsOneWidget);
    expect(find.text('Onboarding cannot restart'), findsOneWidget);

    await tapText(tester, 'Sign in');
    expect(find.text('Sign in to Jitan'), findsOneWidget);
    expect(h.server.requestsTo('/onboarding/complete'), isEmpty, reason: 'onboarding never restarted');
  });

  testWidgets('"Contact HR/Admin" is an instruction, not a button', (tester) async {
    h.server.password = 'set earlier';
    await startApp(tester);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan onboarding QR');

    expect(find.text('Contact HR/Admin'), findsOneWidget);
    expect(find.text('Ask HR/Admin to reset your Jitan account access.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Contact HR/Admin'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('another device finished first: "Sign in" opens sign-in', (tester) async {
    await onboardUpToPassword(tester);
    h.server.anotherDeviceWins = true;
    await enterPasswords(tester, 'correct horse battery', 'correct horse battery');
    expect(find.text('Account was just activated'), findsOneWidget);

    await tapText(tester, 'Sign in');

    expect(find.text('Sign in to Jitan'), findsOneWidget);
  });

  testWidgets('closing the scanner without a QR stays on Join', (tester) async {
    h.scannedValue = null;
    await startApp(tester);
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan onboarding QR');

    expect(find.text('Scan your setup QR'), findsOneWidget);
    expect(h.server.requestsTo('/onboarding/start'), isEmpty);
  });

  testWidgets('lost final response: Try again signs in without repeating onboarding', (tester) async {
    await onboardUpToPassword(tester);
    h.server.loseCompleteResponse = true;

    await enterPasswords(tester, 'correct horse battery', 'correct horse battery');
    expect(find.text('Couldn’t finish setup'), findsOneWidget);

    await tapText(tester, 'Try again');
    expect(find.text('You’re ready.'), findsOneWidget);
  });

  group('app start', () {
    testWidgets('a stored session opens Home directly, authenticated with the bearer token', (tester) async {
      h.server.issuedTokens.add('stored-token');
      h.store.values
        ..['session.token'] = 'stored-token'
        ..['session.expiresAt'] = '2099-01-01T00:00:00.000Z';

      await startApp(tester);

      expect(find.text('Hello, Disan'), findsOneWidget);
      expect(h.server.requestsTo('/me').single.headers['authorization'], 'Bearer stored-token');
    });

    testWidgets('a session the server no longer accepts signs the device out', (tester) async {
      h.store.values
        ..['session.token'] = 'revoked-token'
        ..['session.expiresAt'] = '2099-01-01T00:00:00.000Z';

      await startApp(tester);

      expect(find.text('Sign in to Jitan'), findsOneWidget, reason: 'expired/revoked session → sign-in');
      expect(h.store.values.containsKey('session.token'), isFalse);
    });

    testWidgets('a device signed in before (signed out, expired) opens sign-in; a fresh one onboarding', (tester) async {
      h.store.values['device.signedInBefore'] = 'true';
      await startApp(tester);
      expect(find.text('Sign in to Jitan'), findsOneWidget);
    });

    testWidgets('an expired session is discarded without asking the server', (tester) async {
      h.store.values
        ..['session.token'] = 'old-token'
        ..['session.expiresAt'] = '2020-01-01T00:00:00.000Z';

      await startApp(tester);

      expect(find.text('Get started'), findsOneWidget);
      expect(h.server.requestsTo('/me'), isEmpty);
    });
  });

  group('temporary onboarding QR states', () {
    Future<void> scan(WidgetTester tester, String qr) async {
      h.scannedValue = qr;
      await startApp(tester);
      await tapText(tester, 'Get started');
      await tapText(tester, 'Scan onboarding QR');
    }

    testWidgets('the permanent Terminal QR does not onboard: "QR not recognised"', (tester) async {
      await scan(tester, terminalQr);

      expect(find.text('QR not recognised'), findsOneWidget);
    });

    testWidgets('an expired or replaced QR: "QR expired or used", Try again scans anew', (tester) async {
      h.server.expiredQrs.add(testQr);
      await scan(tester, testQr);

      expect(find.text('QR expired or used'), findsOneWidget);
      expect(find.text('This temporary onboarding QR is no longer valid. Ask HR/Admin to generate a new one.'), findsOneWidget);
      h.server.expiredQrs.clear();
      await tapText(tester, 'Try again');
      expect(find.text('Scan your setup QR'), findsOneWidget);
    });

    testWidgets('an already used QR is refused the same way', (tester) async {
      h.server.usedQrs[testQr] = 'someone';
      await scan(tester, testQr);

      expect(find.text('QR expired or used'), findsOneWidget);
    });

    testWidgets('a recovery QR during onboarding: "Not an onboarding QR"', (tester) async {
      await scan(tester, recoveryQr);

      expect(find.text('Not an onboarding QR'), findsOneWidget);
      expect(h.server.requestsTo('/onboarding/complete'), isEmpty);
    });
  });
}

/// Lets requests, state changes and the 200 ms screen transition finish.
/// (No pumpAndSettle: spinners never settle.)
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
