// ONB-07: the real Employee app on a device/emulator against the real API
// and a freshly seeded database (dev/local-db). Real HTTP, real MySQL, real
// secure storage. Only the camera read and the OS permission prompts are
// stood in: an emulator cannot reliably aim at a QR, and system dialogs
// would block automation. Temporary QRs are generated through the API the
// way HR/Admin does (development identity = HR user 1).
//
//   cd dev/local-db && docker compose down -v && docker compose up -d
//   (API in development mode, JITAN_DEV_USER_ID=1, on port 8080)
//   cd apps/employee_mobile
//   flutter test integration_test --dart-define=JITAN_API_BASE_URL=http://10.0.2.2:8080
//
// Changes the data: re-seed before running again.
import 'dart:convert';

import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:employee_mobile/src/app/employee_services.dart';
import 'package:employee_mobile/src/config/employee_config.dart';
import 'package:employee_mobile/src/device/device_settings.dart';
import 'package:employee_mobile/src/device/permissions_gateway.dart';
import 'package:employee_mobile/src/device/secure_store.dart';
import 'package:employee_mobile/src/device/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';

// Seed fixtures (dev/local-db/seed.sql): permanent Terminal QRs. They must
// never onboard or recover an account.
const _disanTerminalQr = '5xYTglqwzf36v9UidULWYleBWfwt7Cjp';
const _kevinTerminalQr = 'MvrbloqIf-j151FU_94120bzpkqi4K6o';

class _GrantAll implements PermissionsGateway {
  @override
  Future<bool> requestLocation() async => true;

  @override
  Future<bool> requestNotifications() async => true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final config = EmployeeConfig.fromEnvironment() ?? EmployeeConfig.parse('http://10.0.2.2:8080')!;
  const store = PlatformSecureStore();

  /// What the "camera" reads next.
  var scanned = _disanTerminalQr;

  /// HR/Admin "Generate temporary QR" for [userId] in Almeco.
  Future<String> temporaryQr(int userId, String purpose) async {
    final response = await http.post(config.apiBaseUri.resolve('companies/1/employees/$userId/$purpose-qr'));
    expect(response.statusCode, 200, reason: '$purpose QR for $userId');
    return (jsonDecode(response.body) as Map)['qrCode'] as String;
  }

  EmployeeServices services(SessionManager session) {
    final transport = ApiTransport(baseUri: config.apiBaseUri, accessToken: () => session.accessToken);
    final languages = LanguagesApi(transport);
    return EmployeeServices(
      onboardingApi: OnboardingApi(transport),
      recoveryApi: RecoveryApi(transport),
      authApi: AuthApi(transport),
      languagesApi: languages,
      meApi: MeApi(transport),
      translationService: TranslationService(languages),
      session: session,
      settings: const DeviceSettings(store),
      permissions: _GrantAll(),
      scanQr: (_) async => scanned,
      qrScannerView: (onDetected) => Center(
        child: TextButton(onPressed: () => onDetected(scanned), child: const Text('camera reads QR')),
      ),
    );
  }

  /// Pumps until [finder] matches (network calls are real), or fails.
  Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await waitFor(tester, finder);
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapText(WidgetTester tester, String text) => tap(tester, find.text(text));

  Future<void> enter(WidgetTester tester, int field, String text) async {
    await waitFor(tester, find.byType(TextField).at(field));
    await tester.enterText(find.byType(TextField).at(field), text);
    await tester.pump();
  }

  Future<void> signIn(WidgetTester tester, String code, String password) async {
    await waitFor(tester, find.text('Sign in to Jitan'));
    await enter(tester, 0, code);
    await enter(tester, 1, password);
    await tap(tester, find.widgetWithText(FilledButton, 'Sign in'));
  }

  Future<void> signOut(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Profile'));
    await tap(tester, find.widgetWithText(TextButton, 'Sign out'));
    await tap(tester, find.widgetWithText(FilledButton, 'Sign out'));
    await waitFor(tester, find.text('Sign in to Jitan'));
  }

  testWidgets('ONB-07: temporary-QR onboarding, sign-in, refusal, HR reset and temporary-QR recovery', (tester) async {
    for (final key in ['session.token', 'session.expiresAt', 'device.signedInBefore', 'settings.registrationMethod']) {
      await store.delete(key);
    }
    final session = SessionManager(store);
    await tester.pumpWidget(EmployeeApp(services: services(session)));

    // ── The permanent Terminal QR does not onboard ─────────────────────────
    await tapText(tester, 'Get started');
    scanned = _disanTerminalQr;
    await tapText(tester, 'Scan onboarding QR');
    await waitFor(tester, find.text('QR not recognised'));
    await tapText(tester, 'Try again');

    // ── Onboarding: Disan, temporary QR to Home, no second sign-in ─────────
    scanned = await temporaryQr(2, 'onboarding');
    await tapText(tester, 'Scan onboarding QR');
    await waitFor(tester, find.text('Disan Ssebowa'));
    await tapText(tester, 'Yes, this is me');
    await tapText(tester, 'Continue'); // registration method (automatic)
    await tapText(tester, 'Continue'); // permissions
    await waitFor(tester, find.text('Nederlands')); // languages from tblLanguage
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    await tapText(tester, 'Nederlands');
    await tapText(tester, 'Continue');
    await waitFor(tester, find.text('Stel je wachtwoord in')); // tblTranslation (nl)
    await enter(tester, 0, 'Disan-Local-Dev-1');
    await enter(tester, 1, 'Disan-Local-Dev-1');
    await tap(tester, find.widgetWithText(FilledButton, 'Continue'));
    await waitFor(tester, find.text('Je bent klaar.'));
    expect(await store.read('session.token'), isNotNull, reason: 'signed in by onboarding');
    await tapText(tester, 'Start Jitan');
    await waitFor(tester, find.textContaining('Disan'));
    expect(find.byType(TextField), findsNothing, reason: 'no second sign-in screen');

    // ── Sign-out, then normal sign-in (wrong password first) ───────────────
    await signOut(tester);
    await signIn(tester, 'KDV', 'not the password');
    await waitFor(tester, find.text('Couldn’t sign in'));
    await tapText(tester, 'Try again');
    await signIn(tester, 'KDV', 'Kevin-Local-Dev-1');
    await waitFor(tester, find.textContaining('Kevin'));
    final kevinToken = await store.read('session.token');
    expect(kevinToken, isNotNull);

    // ── Inactive / MFD employees cannot sign in ────────────────────────────
    await signOut(tester);
    await signIn(tester, 'FPT', 'Fabian-Local-Dev-1');
    await waitFor(tester, find.text('Account unavailable'));
    await tapText(tester, 'Back');
    await signIn(tester, 'SMA', 'Sara-Local-Dev-1');
    await waitFor(tester, find.text('Account unavailable'));
    await tapText(tester, 'Back');

    // ── Recovery is refused before HR/Admin resets access ──────────────────
    scanned = _kevinTerminalQr;
    await tap(tester, find.widgetWithText(FilledButton, 'Scan QR to recover account'));
    await tapText(tester, 'camera reads QR');
    await waitFor(tester, find.text('Recovery is not available yet.'));
    expect(find.text('Account reset required'), findsOneWidget, reason: 'the Terminal QR does not recover');

    // ── HR/Admin resets Kevin's access (dev identity = HR user 1) ──────────
    final reset = await http.post(config.apiBaseUri.resolve('companies/1/employees/3/reset-access'));
    expect(reset.statusCode, 204);
    final me = await http.get(
      config.apiBaseUri.resolve('me'),
      headers: {'authorization': 'Bearer $kevinToken'},
    );
    expect(me.statusCode, 401, reason: 'the reset revoked Kevin\'s session');

    // ── Temporary recovery QR → new password → Home ───────────────────────
    final recoveryQr = await temporaryQr(3, 'recovery');
    scanned = recoveryQr;
    await tapText(tester, 'Back');
    await tap(tester, find.widgetWithText(FilledButton, 'Scan QR to recover account'));
    await tapText(tester, 'camera reads QR');
    await waitFor(tester, find.text('Set a new password'));
    await enter(tester, 0, 'Kevin-Recovered-2');
    await enter(tester, 1, 'Kevin-Recovered-2');
    await tap(tester, find.widgetWithText(FilledButton, 'Set password & sign in'));
    await waitFor(tester, find.textContaining('Kevin'));
    final recoveredToken = await store.read('session.token');
    expect(recoveredToken, isNot(kevinToken), reason: 'a fresh session');
    final account = await http.get(
      config.apiBaseUri.resolve('me'),
      headers: {'authorization': 'Bearer $recoveredToken'},
    );
    expect((jsonDecode(account.body) as Map)['code'], 'KDV');

    // ── The used recovery QR cannot be used again (Auth / 06C) ─────────────
    await signOut(tester);
    await tap(tester, find.widgetWithText(FilledButton, 'Scan QR to recover account'));
    await tapText(tester, 'camera reads QR');
    await waitFor(tester, find.text('QR expired or used'));
    expect(find.text('New recovery QR required'), findsOneWidget);
  });
}
