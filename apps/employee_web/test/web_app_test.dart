import 'dart:io';

import 'package:employee_web/src/app/web_app.dart';
import 'package:employee_web/src/auth/web_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'support/harness.dart';

void main() {
  Future<void> open(WidgetTester tester, Harness h, {Size size = const Size(1440, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WebApp(services: h.services, translations: h.translations, clock: () => h.now));
    await tester.pumpAndSettle();
  }

  testWidgets('nothing opens without a session, and signing in lands on Home', (tester) async {
    final h = Harness();
    await open(tester, h);
    expect(find.text('Sign in to Jitan'), findsOneWidget);
    expect(find.text('Forgot your password? Ask HR.'), findsOneWidget);
    expect(find.byType(JitanNavItem), findsNothing);

    await tester.enterText(find.byType(TextField).at(0), 'SBW');
    await tester.enterText(find.byType(TextField).at(1), 'a-password');
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(h.session.status, WebSessionStatus.signedIn);
    expect(find.text('Good afternoon'), findsOneWidget);
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the sidebar: four pages, each one working', (tester) async {
    final h = Harness();
    await h.signedIn();
    await open(tester, h);

    expect(find.byType(JitanNavItem), findsNWidgets(4));
    for (final (item, shows) in [('Period', 'Your registered time.'), ('Projects', 'The work you’re assigned to.'), ('Profile', 'Password')]) {
      await tester.tap(find.widgetWithText(JitanNavItem, item));
      await tester.pumpAndSettle();
      expect(find.text(shows), findsOneWidget, reason: item);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a phone has a menu instead of the sidebar', (tester) async {
    final h = Harness();
    await h.signedIn();
    await open(tester, h, size: const Size(390, 844));

    expect(find.byType(JitanNavItem), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(JitanNavItem), findsNWidgets(4));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a session the server ended goes back to sign-in', (tester) async {
    final h = Harness();
    await h.signedIn();
    await open(tester, h);

    h.session.sessionRefused();
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Jitan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('every key has built-in English', () {
    final keyPattern = RegExp(r"static const \w+ = '([^']+)';");
    final keys = {
      for (final match in keyPattern.allMatches(File('lib/src/l10n/employee_web_text_keys.dart').readAsStringSync())) match.group(1)!,
    };
    expect(keys, isNotEmpty);
    final missing = [
      for (final key in keys)
        if (!builtInEnglish.containsKey(key) && !(builtInEnglish.containsKey('$key.one') && builtInEnglish.containsKey('$key.other'))) key,
    ];
    expect(missing, isEmpty);
  });

  test('screens never pass a literal to context.t', () {
    final literalLookup = RegExp(r"""\.t\(\s*['"]""");
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.dart') && literalLookup.hasMatch(file.readAsStringSync())) file.path,
    ];
    expect(offenders, isEmpty);
  });
}
