import 'dart:convert';

import 'package:employee_mobile/src/device/device_settings.dart';
import 'package:employee_mobile/src/onboarding/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import '../support/fake_jitan_server.dart';

void main() {
  late TestHarness h;
  late OnboardingController c;
  final chosenLanguages = <String>[];

  setUp(() {
    h = TestHarness();
    chosenLanguages.clear();
    c = OnboardingController(
      onboardingApi: h.services.onboardingApi,
      languagesApi: h.services.languagesApi,
      session: h.session,
      settings: h.services.settings,
      permissions: h.permissions,
      onLanguageChosen: (code) async => chosenLanguages.add(code),
    );
  });
  tearDown(() => c.dispose());

  /// Scan → confirm → method → permissions → language: at the password step.
  Future<void> toPassword({RegistrationMethod method = RegistrationMethod.automatic}) async {
    c.getStarted();
    await c.submitQr(testQr);
    c.confirmAccount();
    c.chooseMethod(method);
    c.confirmMethod();
    await c.requestPermissions();
    await pumpEventQueue();
    expect(c.step, OnboardingStep.language);
    c.confirmLanguage();
    expect(c.step, OnboardingStep.password);
  }

  Map<String, Object?> lastCompleteBody() =>
      jsonDecode(h.server.requestsTo('/onboarding/complete').last.body) as Map<String, Object?>;

  group('happy path', () {
    test('ends signed in on this device: no separate sign-in', () async {
      c.getStarted();
      await c.submitQr(testQr);
      expect(c.step, OnboardingStep.confirm);
      expect(c.account?.firstName, 'Disan');

      c.confirmAccount();
      expect(c.step, OnboardingStep.method);
      c.confirmMethod();
      await c.requestPermissions();
      await pumpEventQueue();
      expect(c.step, OnboardingStep.language, reason: 'Figma 06B: language after permissions');
      expect(c.languages.map((l) => l.code), ['en', 'nl', 'fr', 'de'], reason: 'English always first, then the database');
      await c.chooseLanguage('nl');
      expect(chosenLanguages, ['nl'], reason: 'applied to the app at once');
      c.confirmLanguage();
      expect(c.step, OnboardingStep.password);
      await c.submitPassword('correct horse battery', 'correct horse battery');

      expect(c.step, OnboardingStep.ready);
      expect(h.session.isSignedIn, isTrue);
      expect(h.session.accessToken, h.server.issuedTokens.single);
      final body = lastCompleteBody();
      expect(body['languageCode'], 'nl');
      expect(body['deviceId'], await h.session.deviceId());
      expect(await h.services.settings.registrationMethod(), RegistrationMethod.automatic);
    });

    test('automatic registration asks for location and notifications; manual only notifications', () async {
      await toPassword();
      expect(h.permissions.asked, ['location', 'notifications']);

      h = TestHarness();
      c = OnboardingController(
        onboardingApi: h.services.onboardingApi,
        languagesApi: h.services.languagesApi,
        session: h.session,
        settings: h.services.settings,
        permissions: h.permissions,
        onLanguageChosen: (_) async {},
      );
      await toPassword(method: RegistrationMethod.manual);
      expect(h.permissions.asked, ['notifications']);
      expect(await h.services.settings.registrationMethod(), RegistrationMethod.manual);
    });

    test('a refused location permission never blocks onboarding; Ready says it is missing', () async {
      h.permissions.grantLocation = false;
      await toPassword();
      await c.submitPassword('correct horse battery', 'correct horse battery');

      expect(c.step, OnboardingStep.ready);
      expect(c.locationMissing, isTrue);
    });

    test('languages that fail to load leave English available', () async {
      h.server.dropNext.add('/languages');
      await c.submitQr(testQr);
      c.confirmAccount();
      c.confirmMethod();
      await c.requestPermissions();
      await pumpEventQueue();

      expect(c.languages.map((l) => l.code), ['en']);
      expect(c.languagesFailed, isTrue);
    });
  });

  group('password (mandatory)', () {
    test('too short, only spaces, too long or not confirmed: refused before any request', () async {
      await toPassword();
      for (final (password, confirmation, problem) in [
        ('short', 'short', PasswordProblem.tooShort),
        ('        ', '        ', PasswordProblem.tooShort),
        ('x' * 257, 'x' * 257, PasswordProblem.tooLong),
        ('correct horse', 'correct house', PasswordProblem.mismatch),
      ]) {
        await c.submitPassword(password, confirmation);
        expect(c.passwordProblem, problem);
      }
      expect(h.server.requestsTo('/onboarding/complete'), isEmpty);
      expect(c.step, OnboardingStep.password);
    });

    test('8 characters are enough; 12+ is only a recommendation', () async {
      await toPassword();
      await c.submitPassword('8 chars!', '8 chars!');
      expect(c.step, OnboardingStep.ready);
    });
  });

  group('scan errors', () {
    test('unknown QR → "QR not recognised"; retry goes back to scanning', () async {
      await c.submitQr('not-a-jitan-qr');
      expect((c.step, c.problem), (OnboardingStep.error, OnboardingProblem.invalidQr));

      await c.retry();
      expect(c.step, OnboardingStep.join);
    });

    test('already onboarded QR → "Account already activated" (never restarts onboarding)', () async {
      h.server.password = 'set earlier';
      await c.submitQr(testQr);
      expect(c.problem, OnboardingProblem.alreadyActivated);
    });

    test('inactive employee → "Account can’t be activated"', () async {
      h.server.active = false;
      await c.submitQr(testQr);
      expect(c.problem, OnboardingProblem.accountUnavailable);
    });

    test('server unreachable → "temporarily unavailable"; retry rechecks the same QR', () async {
      h.server.dropNext.add('/onboarding/start');
      await c.submitQr(testQr);
      expect(c.problem, OnboardingProblem.serverUnavailable);

      await c.retry();
      expect(c.step, OnboardingStep.confirm);
    });
  });

  group('final step', () {
    test('lost response: "Couldn’t finish setup", retry recovers the session without repeating onboarding', () async {
      await toPassword();
      h.server.loseCompleteResponse = true;

      await c.submitPassword('correct horse battery', 'correct horse battery');
      expect(c.problem, OnboardingProblem.networkFailure);
      expect(h.session.isSignedIn, isFalse);
      expect(h.server.password, 'correct horse battery', reason: 'the server did complete');

      await c.retry();
      expect(c.step, OnboardingStep.ready);
      expect(h.session.accessToken, h.server.issuedTokens.single);
      expect(lastCompleteBody()['password'], 'correct horse battery', reason: 'same password, no retyping');
    });

    test('another device completed first → "Account was just activated"', () async {
      await toPassword();
      h.server.anotherDeviceWins = true;

      await c.submitPassword('correct horse battery', 'correct horse battery');

      expect(c.problem, OnboardingProblem.activatedElsewhere);
      expect(h.session.isSignedIn, isFalse);
    });

    test('session cannot be stored → "Setup completed, sign-in pending"; Retry sign-in finishes', () async {
      await toPassword();
      await h.session.deviceId(); // created before storage fails
      h.store.failWrites = true;

      await c.submitPassword('correct horse battery', 'correct horse battery');
      expect(c.problem, OnboardingProblem.sessionRecovery);

      h.store.failWrites = false;
      await c.retry();
      expect(c.step, OnboardingStep.ready);
      expect(h.session.isSignedIn, isTrue);
      expect(h.server.requestsTo('/onboarding/complete'), hasLength(2));
    });

    test('a password the server refuses returns to the password step', () async {
      await toPassword();
      h.server.rejectPassword = true;

      await c.submitPassword('correct horse battery', 'correct horse battery');

      expect((c.step, c.passwordProblem), (OnboardingStep.password, PasswordProblem.rejected));
      expect(h.session.isSignedIn, isFalse);
    });
  });

  test('the password never appears in client logs, also when the final step fails', () async {
    const password = 'Unmistakable-Pass-4471';
    final records = <String>[];
    final previous = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((r) => records.add('${r.message} ${r.error ?? ''}'));
    addTearDown(() {
      subscription.cancel();
      Logger.root.level = previous;
    });

    await toPassword();
    h.server.loseCompleteResponse = true;
    await c.submitPassword(password, password);
    h.store.failWrites = true;
    await c.retry();
    h.store.failWrites = false;
    await c.retry();

    expect(c.step, OnboardingStep.ready);
    expect(records, isNotEmpty, reason: 'failures were logged');
    for (final record in records) {
      expect(record, isNot(contains(password)));
      expect(record, isNot(contains(testQr)), reason: 'the QR is a credential too');
    }
  });

  test('back walks the steps in reverse and forgets the scanned account at the scanner', () async {
    await toPassword();
    for (final expected in [
      OnboardingStep.language,
      OnboardingStep.permissions,
      OnboardingStep.method,
      OnboardingStep.confirm,
      OnboardingStep.join,
    ]) {
      expect(c.back(), isTrue);
      expect(c.step, expected);
    }
    expect(c.account, isNull);
  });
}
