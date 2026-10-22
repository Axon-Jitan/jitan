import 'dart:convert';

import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_jitan_server.dart';

const _password = 'correct horse battery';

void main() {
  late TestHarness h;

  /// An activated employee (SBW) whose device has no session, e.g. after a
  /// reinstall or sign-out.
  setUp(() {
    h = TestHarness();
    h.server.password = _password;
    h.store.values['device.signedInBefore'] = 'true';
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EmployeeApp(services: h.services));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) => tap(tester, find.text(text));

  /// Sign-in form: code field, password field, "Sign in" button.
  Future<void> signIn(WidgetTester tester, {String code = 'SBW', String password = _password}) async {
    await tester.enterText(find.byType(TextField).at(0), code);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.pump();
    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  }

  group('Auth / 01 Sign in', () {
    testWidgets('code + password opens Home directly with an authenticated device session', (tester) async {
      await startApp(tester);
      expect(find.text('Sign in to Jitan'), findsOneWidget);

      await signIn(tester);

      expect(find.text('Good morning, Disan.'), findsOneWidget);
      final token = h.store.values['session.token'];
      expect(h.server.issuedTokens, contains(token));
      final body = jsonDecode(h.server.requestsTo('/auth/sign-in').single.body) as Map;
      expect(body['deviceId'], h.store.values['device.id'], reason: 'session for this device');
    });

    testWidgets('wrong password and unknown code: the same "Couldn’t sign in", then try again', (tester) async {
      await startApp(tester);

      await signIn(tester, password: 'wrong password');
      expect(find.text('Couldn’t sign in'), findsOneWidget);
      expect(find.text('Try again with your employee code and password. Jitan won’t reveal which field was wrong.'), findsOneWidget);

      await tapText(tester, 'Try again');
      await signIn(tester, code: 'NOBODY');
      expect(find.text('Couldn’t sign in'), findsOneWidget);

      await tapText(tester, 'Try again');
      await signIn(tester);
      expect(find.text('Good morning, Disan.'), findsOneWidget);
    });

    testWidgets('inactive or MFD account: "Account unavailable"', (tester) async {
      h.server.active = false;
      await startApp(tester);

      await signIn(tester);

      expect(find.text('Account unavailable'), findsOneWidget);
      expect(h.store.values.containsKey('session.token'), isFalse);
    });

    testWidgets('network failure: "Can’t reach Jitan", retry signs in; the password is untouched', (tester) async {
      await startApp(tester);
      h.server.dropNext.add('/auth/sign-in');

      await signIn(tester);
      expect(find.text('Can’t reach Jitan'), findsOneWidget);
      expect(find.text('Your password has not been changed. Check your connection and retry.'), findsOneWidget);
      expect(h.server.password, _password);

      await tapText(tester, 'Try again');
      expect(find.text('Good morning, Disan.'), findsOneWidget);
    });

    testWidgets('a first-time employee goes back to onboarding from sign-in', (tester) async {
      await startApp(tester);

      await tapText(tester, 'Set up with my QR');

      expect(find.text('Get started'), findsOneWidget);
      await tapText(tester, 'Already activated? Sign in');
      expect(find.text('Sign in to Jitan'), findsOneWidget);
    });
  });

  group('Auth / 02 Forgot password', () {
    testWidgets('entering the code resets nothing and leads to "Recover with QR" (ask HR/Admin first)', (
      tester,
    ) async {
      await startApp(tester);
      await tapText(tester, 'Forgot password?');
      expect(find.text('Enter your employee code to start account recovery.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'SBW');
      await tester.pump();
      await tapText(tester, 'Continue');

      expect(find.text('Recover account'), findsOneWidget);
      expect(
        find.text('Ask HR/Admin to reset your account and generate a temporary recovery QR. Then scan it here.'),
        findsOneWidget,
      );
      expect(h.server.requests, isEmpty, reason: 'the employee code alone sends and resets nothing');
      expect(h.server.password, _password);

      await tapText(tester, 'Back');
      expect(find.text('Sign in to Jitan'), findsOneWidget);
    });

    testWidgets('reachable from "Couldn’t sign in"', (tester) async {
      await startApp(tester);
      await signIn(tester, password: 'wrong password');

      await tap(tester, find.widgetWithText(FilledButton, 'Forgot password'));

      expect(find.text('Enter your employee code to start account recovery.'), findsOneWidget);
    });
  });

  group('Profile', () {
    /// Current / new / confirm, then "Change password".
    Future<void> fillChange(WidgetTester tester, {required String current, required String password, String? confirmation}) async {
      await tester.enterText(find.byType(TextField).at(0), current);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.enterText(find.byType(TextField).at(2), confirmation ?? password);
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));
    }

    Future<void> openPasswordScreen(WidgetTester tester) async {
      await startApp(tester);
      await signIn(tester);
      await tap(tester, find.text('Profile'));
      expect(find.text('SBW'), findsOneWidget);
      await tapText(tester, 'Password & web login');
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));
    }

    testWidgets('a signed-in employee changes the password; this device stays signed in, others are signed out', (
      tester,
    ) async {
      await openPasswordScreen(tester);
      expect(find.text('Current password'), findsOneWidget);
      final oldToken = h.store.values['session.token'];

      await fillChange(tester, current: _password, password: 'a brand new password');

      expect(find.text('Password changed.'), findsOneWidget);
      expect(h.server.password, 'a brand new password');
      final newToken = h.store.values['session.token'];
      expect(newToken, isNot(oldToken), reason: 'this device keeps a (new) session');
      expect(h.server.issuedTokens, [newToken], reason: 'other sessions revoked');
      expect(jsonDecode(h.server.requestsTo('/me/password').single.body), {
        'currentPassword': _password,
        'newPassword': 'a brand new password',
      });
    });

    testWidgets('a wrong current password is an inline error; nothing changes', (tester) async {
      await openPasswordScreen(tester);

      await fillChange(tester, current: 'not my password', password: 'a brand new password');

      expect(find.text('The current password is incorrect.'), findsOneWidget);
      expect(h.server.password, _password);
      expect(h.server.issuedTokens, contains(h.store.values['session.token']), reason: 'still signed in');
    });

    testWidgets('mismatch and too short are inline; network failure leaves the password unchanged', (tester) async {
      await openPasswordScreen(tester);

      await fillChange(tester, current: _password, password: 'short');
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      await fillChange(tester, current: _password, password: 'a brand new password', confirmation: 'a brand new passwort');
      expect(find.text('Passwords don’t match.'), findsOneWidget);
      expect(h.server.requestsTo('/me/password'), isEmpty);

      h.server.dropNext.add('/me/password');
      await fillChange(tester, current: _password, password: 'a brand new password');
      expect(find.text('Can’t reach Jitan. Your password has not been changed.'), findsOneWidget);
      expect(h.server.password, _password);
    });

    testWidgets('sign out asks first, then opens sign-in; the session is gone', (tester) async {
      await startApp(tester);
      await signIn(tester);
      await tap(tester, find.text('Profile'));

      await tap(tester, find.widgetWithText(TextButton, 'Sign out'));
      expect(find.text('Sign out of Jitan?'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));

      expect(find.text('Sign in to Jitan'), findsOneWidget);
      expect(h.store.values.containsKey('session.token'), isFalse);
    });
  });

  group('Auth / 06–07 Recover with a temporary recovery QR', () {
    Future<void> openRecovery(WidgetTester tester) async {
      await startApp(tester);
      await tap(tester, find.widgetWithText(FilledButton, 'Scan QR to recover account'));
      expect(find.text('Recover account'), findsOneWidget);
      expect(find.text('HR/Admin reset required'), findsOneWidget);
      expect(find.text('Recovery codes expire after 10 minutes and can only be used once.'), findsOneWidget);
    }

    Future<void> setNewPassword(WidgetTester tester, String password) async {
      expect(find.text('Set a new password'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), password);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tap(tester, find.widgetWithText(FilledButton, 'Set password & sign in'));
    }

    testWidgets('before HR/Admin resets access (06B): refused, nothing changes, not resent', (tester) async {
      h.scannedValue = recoveryQr;
      await openRecovery(tester);

      await tap(tester, find.byKey(fakeCameraKey));
      await tap(tester, find.byKey(fakeCameraKey));

      expect(find.text('Recover account'), findsOneWidget, reason: 'still scanning');
      expect(find.text('Recovery is not available yet.'), findsOneWidget);
      expect(find.text('Account reset required'), findsOneWidget);
      expect(find.text('Ask HR/Admin to reset access and generate a new temporary recovery QR.'), findsOneWidget);
      expect(h.server.requestsTo('/recovery/start'), hasLength(1), reason: 'the refused QR is not resent');
      expect(h.server.password, _password);
      expect(h.store.values.containsKey('session.token'), isFalse);
    });

    testWidgets('the permanent Terminal QR cannot recover an account', (tester) async {
      h.server.password = null;
      h.scannedValue = terminalQr;
      await openRecovery(tester);

      await tap(tester, find.byKey(fakeCameraKey));

      expect(find.text('Recovery is not available yet.'), findsOneWidget);
      expect(find.text('Set a new password'), findsNothing);
    });

    testWidgets('after the reset: scan the recovery QR, set a new password, land on Home', (tester) async {
      // Signed in, then HR/Admin resets access: the password is cleared and
      // every session ends (the server refuses the old token).
      await startApp(tester);
      await signIn(tester);
      final oldToken = h.store.values['session.token'];
      h.server
        ..password = null
        ..issuedTokens.clear();
      await tester.pumpWidget(const SizedBox());
      await startApp(tester);
      expect(find.text('Sign in to Jitan'), findsOneWidget, reason: 'the old session is revoked');

      h.scannedValue = recoveryQr;
      await tap(tester, find.widgetWithText(FilledButton, 'Scan QR to recover account'));
      await tap(tester, find.byKey(fakeCameraKey));
      expect(
        find.text('Your temporary recovery QR was verified. Set a new password to finish account recovery.'),
        findsOneWidget,
      );
      expect(find.text('Your Terminal QR stays the same'), findsOneWidget);
      await setNewPassword(tester, 'my new password');

      expect(find.text('Good morning, Disan.'), findsOneWidget, reason: 'straight to Home');
      expect(h.server.password, 'my new password');
      final newToken = h.store.values['session.token'];
      expect(newToken, isNot(oldToken));
      expect(h.server.issuedTokens, [newToken], reason: 'a fresh session');
      final body = jsonDecode(h.server.requestsTo('/recovery/complete').single.body) as Map;
      expect(body['qrCode'], recoveryQr);
      expect(h.server.requestsTo('/onboarding/complete'), isEmpty);
    });

    testWidgets('the used recovery QR cannot be used again: Auth / 06C "QR expired or used"', (tester) async {
      h.server.password = null;
      h.scannedValue = recoveryQr;
      await openRecovery(tester);
      await tap(tester, find.byKey(fakeCameraKey));
      await setNewPassword(tester, 'my new password');
      expect(find.text('Good morning, Disan.'), findsOneWidget);

      // Sign out, then try the same QR again.
      await tap(tester, find.text('Profile'));
      await tap(tester, find.widgetWithText(TextButton, 'Sign out'));
      await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await tap(tester, find.widgetWithText(FilledButton, 'Scan QR to recover account'));
      await tap(tester, find.byKey(fakeCameraKey));

      expect(find.text('QR expired or used'), findsOneWidget);
      expect(find.text('This temporary recovery QR is no longer valid. Ask HR/Admin to generate a new one.'), findsOneWidget);
      expect(find.text('New recovery QR required'), findsOneWidget);
      expect(find.text('The old QR cannot be reused. Your Terminal QR is unaffected.'), findsOneWidget);
      expect(find.text('Scan a new temporary recovery QR'), findsOneWidget);
      expect(find.text('Set a new password'), findsNothing);
      expect(h.server.password, 'my new password');
    });

    testWidgets('an expired recovery QR: 06C', (tester) async {
      h.server
        ..password = null
        ..expiredQrs.add(recoveryQr);
      h.scannedValue = recoveryQr;
      await openRecovery(tester);

      await tap(tester, find.byKey(fakeCameraKey));

      expect(find.text('QR expired or used'), findsOneWidget);
    });

    testWidgets('new password rules are inline on "Set a new password"', (tester) async {
      h.server.password = null;
      h.scannedValue = recoveryQr;
      await openRecovery(tester);
      await tap(tester, find.byKey(fakeCameraKey));

      await tester.enterText(find.byType(TextField).at(0), 'my new password');
      await tester.enterText(find.byType(TextField).at(1), 'my new passwort');
      await tap(tester, find.widgetWithText(FilledButton, 'Set password & sign in'));

      expect(find.text('Passwords don’t match.'), findsOneWidget);
      expect(h.server.requestsTo('/recovery/complete'), isEmpty);
    });

    testWidgets('network failure while setting the new password: "Can’t reach Jitan", retry finishes once', (
      tester,
    ) async {
      h.server.password = null;
      h.scannedValue = recoveryQr;
      await openRecovery(tester);
      await tap(tester, find.byKey(fakeCameraKey));
      h.server.dropNext.add('/recovery/complete');

      await setNewPassword(tester, 'my new password');
      expect(find.text('Can’t reach Jitan'), findsOneWidget);

      await tapText(tester, 'Try again');
      expect(find.text('Good morning, Disan.'), findsOneWidget);
      expect(h.server.password, 'my new password');
    });
  });
}
