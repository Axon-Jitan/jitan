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

      expect(find.text('Hello, Disan'), findsOneWidget);
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
      expect(find.text('Hello, Disan'), findsOneWidget);
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
      expect(find.text('Hello, Disan'), findsOneWidget);
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
    testWidgets('entering the code resets nothing and tells the employee to contact HR/Admin', (tester) async {
      await startApp(tester);
      await tapText(tester, 'Forgot password?');
      expect(find.text('Enter your employee code to start account recovery.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'SBW');
      await tester.pump();
      await tapText(tester, 'Continue');

      expect(find.text('Contact HR/Admin to reset your Jitan access.'), findsOneWidget);
      expect(find.text('Your employee code: SBW'), findsOneWidget);
      expect(h.server.requests, isEmpty, reason: 'nothing is sent, nothing is reset');
      expect(h.server.password, _password);

      await tapText(tester, 'Back to sign in');
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
    Future<void> openPasswordScreen(WidgetTester tester) async {
      await startApp(tester);
      await signIn(tester);
      await tap(tester, find.byTooltip('Profile'));
      expect(find.text('SBW'), findsOneWidget);
      await tapText(tester, 'Password & web login');
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));
    }

    testWidgets('a signed-in employee changes the password; this device stays signed in, others are signed out', (
      tester,
    ) async {
      await openPasswordScreen(tester);
      final oldToken = h.store.values['session.token'];

      await tester.enterText(find.byType(TextField).at(0), 'a brand new password');
      await tester.enterText(find.byType(TextField).at(1), 'a brand new password');
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));

      expect(find.text('Password changed.'), findsOneWidget);
      expect(h.server.password, 'a brand new password');
      final newToken = h.store.values['session.token'];
      expect(newToken, isNot(oldToken));
      expect(h.server.issuedTokens, [newToken], reason: 'old sessions revoked');
      expect(jsonDecode(h.server.requestsTo('/me/password').single.body), {'newPassword': 'a brand new password'});
    });

    testWidgets('mismatch and too short are inline; network failure leaves the password unchanged', (tester) async {
      await openPasswordScreen(tester);

      await tester.enterText(find.byType(TextField).at(0), 'short');
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'a brand new password');
      await tester.enterText(find.byType(TextField).at(1), 'a brand new passwort');
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));
      expect(find.text('Passwords don’t match.'), findsOneWidget);
      expect(h.server.requestsTo('/me/password'), isEmpty);

      h.server.dropNext.add('/me/password');
      await tester.enterText(find.byType(TextField).at(1), 'a brand new password');
      await tap(tester, find.widgetWithText(FilledButton, 'Change password'));
      expect(find.text('Can’t reach Jitan. Your password has not been changed.'), findsOneWidget);
      expect(h.server.password, _password);
    });

    testWidgets('sign out asks first, then opens sign-in; the session is gone', (tester) async {
      await startApp(tester);
      await signIn(tester);
      await tap(tester, find.byTooltip('Profile'));

      await tap(tester, find.widgetWithText(TextButton, 'Sign out'));
      expect(find.text('Sign out of Jitan?'), findsOneWidget);
      await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));

      expect(find.text('Sign in to Jitan'), findsOneWidget);
      expect(h.store.values.containsKey('session.token'), isFalse);
    });
  });

  testWidgets('after HR/Admin resets access, the session ends and the existing QR sets up a new password', (
    tester,
  ) async {
    // Signed in, then HR/Admin resets access: the server clears the password
    // and every session ends.
    await startApp(tester);
    await signIn(tester);
    h.server
      ..password = null
      ..issuedTokens.clear();

    // Next start: the session is refused → sign-in → back to onboarding.
    await tester.pumpWidget(const SizedBox());
    await startApp(tester);
    expect(find.text('Sign in to Jitan'), findsOneWidget);
    await tapText(tester, 'Set up with my QR');
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan QR');
    await tapText(tester, 'Yes, this is me');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    await tester.enterText(find.byType(TextField).at(0), 'my new password');
    await tester.enterText(find.byType(TextField).at(1), 'my new password');
    await tapText(tester, 'Continue');

    expect(find.text('You’re ready.'), findsOneWidget);
    expect(h.server.password, 'my new password');
    expect(h.server.issuedTokens, [h.store.values['session.token']], reason: 'a fresh session');
  });
}
