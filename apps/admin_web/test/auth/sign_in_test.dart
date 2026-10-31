import 'package:admin_web/src/app/admin_app.dart';
import 'package:admin_web/src/auth/admin_session.dart';
import 'package:admin_web/src/auth/platform/session_store.dart';
import 'package:admin_web/src/auth/session_http_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_auth.dart';
import '../support/test_services.dart';

void main() {
  late FakeAuthApi auth;
  late FakeMeApi me;
  late AllCompaniesApi companies;
  late MemorySessionStore store;
  late DateTime now;

  AdminSession session() => AdminSession(auth: auth, me: me, companies: companies, store: store, clock: () => now);

  setUp(() {
    auth = FakeAuthApi();
    me = FakeMeApi();
    companies = AllCompaniesApi();
    store = MemorySessionStore();
    now = DateTime(2026, 10, 31, 9);
  });

  group('the session', () {
    test('sign in keeps the token for its 30 days, and the account', () async {
      final s = session();

      await s.signIn('SBW', 'a password');

      expect(s.status, AdminSessionStatus.signedIn);
      expect(s.account?.code, 'SBW');
      expect(store.read('jitan.session.token'), 'token-1');
      expect(auth.requests.single.code, 'SBW');
    });

    test('the same browser keeps one device id, a UUID the server accepts', () async {
      final s = session();

      await s.signIn('SBW', 'a password');
      await s.signIn('SBW', 'a password');

      final ids = auth.requests.map((r) => r.deviceId).toSet();
      expect(ids, hasLength(1));
      expect(ids.single, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });

    test('reopening the browser: still signed in, without a password', () async {
      await session().signIn('SBW', 'a password');

      final reopened = session();
      await reopened.restore();

      expect(reopened.status, AdminSessionStatus.signedIn);
      expect(reopened.token, 'token-1');
      expect(auth.requests, hasLength(1));
    });

    test('after the 30 days: signed out, and nothing stays stored', () async {
      await session().signIn('SBW', 'a password');
      now = now.add(const Duration(days: 31));

      final reopened = session();
      await reopened.restore();

      expect(reopened.status, AdminSessionStatus.signedOut);
      expect(store.read('jitan.session.token'), isNull);
    });

    test('a session the server no longer accepts ends', () async {
      await session().signIn('SBW', 'a password');
      me.failure = const ApiClientException.server(401, ApiError(code: 'unauthenticated', message: 'x'));

      final reopened = session();
      await reopened.restore();

      expect(reopened.status, AdminSessionStatus.signedOut);
    });

    test('offline when reopening: stays signed in', () async {
      await session().signIn('SBW', 'a password');
      me.failure = const ApiClientException.network('offline');

      final reopened = session();
      await reopened.restore();

      expect(reopened.status, AdminSessionStatus.signedIn);
    });

    test('the server refuses HR access: no access, decided by its answer', () async {
      companies.failure = const ApiClientException.server(403, ApiError(code: ApiErrorCode.forbidden, message: 'x'));
      final s = session();

      await s.signIn('EMU1', 'a password');

      expect(s.status, AdminSessionStatus.noAccess);
    });

    test('sign out forgets the token and keeps the device id', () async {
      final s = session();
      await s.signIn('SBW', 'a password');

      s.signOut();

      expect((s.status, s.token, s.account), (AdminSessionStatus.signedOut, null, null));
      expect(store.read('jitan.session.token'), isNull);
      expect(store.read('jitan.device.id'), isNotNull);
    });

    test('any page getting a 401 ends the session; a wrong password does not', () async {
      var refused = 0;
      final client = SessionHttpClient(() => refused++, inner: MockClient((_) async => http.Response('{}', 401)));

      await client.get(Uri.parse('http://api.test/auth/sign-in'));
      expect(refused, 0);

      await client.get(Uri.parse('http://api.test/companies'));
      expect(refused, 1);
    });
  });

  group('the screens (Figma 1469)', () {
    Future<void> pump(WidgetTester tester, AdminSession session) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fakes = TestServices(session: session);
      await tester.pumpWidget(TranslationScope(
        translations: Translations.english(),
        child: AdminApp(services: fakes.services, initialLocation: '/time-records'),
      ));
      await tester.pumpAndSettle();
    }

    JitanPrimaryButton signInButton(WidgetTester tester) => tester.widget(find.byType(JitanPrimaryButton));

    Future<void> enter(WidgetTester tester, String code, String password) async {
      await tester.enterText(find.byType(TextField).first, code);
      await tester.enterText(find.byType(TextField).last, password);
      await tester.pump();
    }

    testWidgets('signed out: only the sign-in card; the button waits for both fields', (tester) async {
      await pump(tester, session());

      expect(find.text('Sign in to Jitan'), findsOneWidget);
      expect(find.byType(JitanNavItem), findsNothing);
      expect(signInButton(tester).onPressed, isNull);

      await enter(tester, 'SBW', 'a password');
      expect(signInButton(tester).onPressed, isNotNull);
    });

    testWidgets('wrong code or password: one generic message, and the fields stay', (tester) async {
      await pump(tester, session());
      await enter(tester, 'SBW', 'wrong');
      auth.failure = const ApiClientException.server(401, ApiError(code: ApiErrorCode.invalidCredentials, message: 'x'));

      await tester.tap(find.byType(JitanPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('That code and password don’t match.'), findsOneWidget);
      expect(find.text('SBW'), findsOneWidget);
    });

    for (final (what, failure, message) in [
      ('a switched-off account', const ApiClientException.server(403, ApiError(code: ApiErrorCode.accountInactive, message: 'x')), 'This account is not available. Ask your administrator.'),
      ('too many attempts', const ApiClientException.server(429, ApiError(code: ApiErrorCode.tooManyAttempts, message: 'x')), 'Too many attempts. Try again in 15 minutes.'),
      ('no connection', const ApiClientException.network('offline'), 'Jitan can’t be reached. Check your connection and try again.'),
    ]) {
      testWidgets('$what says so', (tester) async {
        await pump(tester, session());
        await enter(tester, 'SBW', 'a password');
        auth.failure = failure;

        await tester.tap(find.byType(JitanPrimaryButton));
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('signed in: the pages open, with the person and Sign out in the sidebar', (tester) async {
      await pump(tester, session());
      await enter(tester, 'SBW', 'a password');

      await tester.tap(find.byType(JitanPrimaryButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(JitanNavItem), findsNWidgets(7));
      expect(find.text('Disan Ssebowa'), findsOneWidget);
      expect(
        tester.widget<JitanNavItem>(find.widgetWithText(JitanNavItem, 'Time records')).selected,
        true,
        reason: 'the page asked for before signing in',
      );

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sign in to Jitan'), findsOneWidget);
    });

    testWidgets('no HR access: says so, and offers Sign out', (tester) async {
      companies.failure = const ApiClientException.server(403, ApiError(code: ApiErrorCode.forbidden, message: 'x'));
      await pump(tester, session());
      await enter(tester, 'EMU1', 'a password');

      await tester.tap(find.byType(JitanPrimaryButton));
      await tester.pumpAndSettle();

      expect(find.text('No HR access yet'), findsOneWidget);
      expect(find.byType(JitanNavItem), findsNothing);
    });

    for (final width in [390.0, 2400.0]) {
      testWidgets('sign-in fits at $width px', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(TranslationScope(
          translations: Translations.english(),
          child: AdminApp(services: TestServices(session: session()).services),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Sign in to Jitan'), findsOneWidget);
      });
    }
  });

}
