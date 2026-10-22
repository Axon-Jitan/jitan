// Emulator visual review: walks the real app through every onboarding,
// error and auth screen and saves a screenshot of each, for comparison with
// Figma (01 — Employee App). The API is the in-memory fake server of the
// widget tests, so every state is reachable, including network failures.
//
//   cd apps/employee_mobile
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/visual_review_test.dart -d emulator-5554 \
//     --dart-define=JITAN_VISUAL_REVIEW=true
//
// Screenshots: apps/employee_mobile/build/visual_review/<name>.png
import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:employee_mobile/src/app/employee_services.dart';
import 'package:employee_mobile/src/device/device_settings.dart';
import 'package:employee_mobile/src/device/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';

import '../test/support/fake_jitan_server.dart';

const _enabled = bool.fromEnvironment('JITAN_VISUAL_REVIEW');
const _camera = ValueKey('visual-review-camera');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceReady = false;

  late FakeJitanServer server;
  late MemorySecureStore store;
  String? scanned;

  Future<void> start(WidgetTester tester, {bool signedInBefore = false, void Function()? arrange}) async {
    surfaceReady = false;
    server = FakeJitanServer();
    store = MemorySecureStore();
    // An existing installation id, so a storage failure hits the session save.
    store.values['device.id'] = 'visual-review-device-0001';
    if (signedInBefore) store.values['device.signedInBefore'] = 'true';
    arrange?.call();
    final session = SessionManager(store);
    final transport = ApiTransport(
      baseUri: Uri.parse('http://api.test/'),
      httpClient: server.client,
      accessToken: () => session.accessToken,
    );
    final languages = LanguagesApi(transport);
    await tester.pumpWidget(
      EmployeeApp(
        services: EmployeeServices(
          onboardingApi: OnboardingApi(transport),
          recoveryApi: RecoveryApi(transport),
          authApi: AuthApi(transport),
          languagesApi: languages,
          meApi: MeApi(transport),
          timeRegistrationsApi: TimeRegistrationsApi(transport),
          translationService: TranslationService(languages),
          session: session,
          settings: DeviceSettings(store),
          permissions: FakePermissions(),
          // An invisible tap target over the (dark) camera preview: the frame
          // looks as in Figma, and a tap "reads" [scanned].
          qrScannerView: (onDetected) => GestureDetector(
            key: _camera,
            behavior: HitTestBehavior.opaque,
            onTap: () => onDetected(scanned!),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    if (!surfaceReady) {
      await binding.convertFlutterSurfaceToImage();
      surfaceReady = true;
      await settle(tester);
    }
    await binding.takeScreenshot(name);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> scan(WidgetTester tester, String qr) async {
    scanned = qr;
    await tester.tap(find.byKey(_camera));
    await settle(tester);
  }

  Future<void> enterPasswords(WidgetTester tester, String password, String confirmation, String action) async {
    await tester.enterText(find.byType(TextField).at(0), password);
    await tester.enterText(find.byType(TextField).at(1), confirmation);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tapText(tester, action);
  }

  /// Fills the sign-in form; [password] alone when the code is already there.
  Future<void> signIn(WidgetTester tester, {String? code, required String password}) async {
    if (code != null) await tester.enterText(find.byType(TextField).at(0), code);
    await tester.enterText(find.byType(TextField).at(1), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);
    await tapText(tester, 'Sign in');
  }

  Future<void> toScanner(WidgetTester tester) async {
    await tapText(tester, 'Get started');
    await tapText(tester, 'Scan onboarding QR');
  }

  Future<void> toPassword(WidgetTester tester) async {
    await toScanner(tester);
    await scan(tester, testQr);
    await tapText(tester, 'Continue to account');
    await tapText(tester, 'Yes, this is me');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
  }

  group('visual review', skip: _enabled ? false : 'Run with --dart-define=JITAN_VISUAL_REVIEW=true', () {
    testWidgets('onboarding, happy path', (tester) async {
      await start(tester);
      await shot(tester, 'onb_01_welcome');
      await tapText(tester, 'Get started');
      await shot(tester, 'onb_02_join');
      await tapText(tester, 'Scan onboarding QR');
      await shot(tester, 'onb_02B_scan');
      await scan(tester, testQr);
      await shot(tester, 'onb_03B_verified');
      await tapText(tester, 'Continue to account');
      await shot(tester, 'onb_04_account_found');
      await tapText(tester, 'Yes, this is me');
      await shot(tester, 'onb_05_method');
      await tapText(tester, 'Continue');
      await shot(tester, 'onb_06_permissions');
      await tapText(tester, 'Continue');
      await shot(tester, 'onb_06B_language');
      await tapText(tester, 'Continue');
      await shot(tester, 'onb_07_password');
      await enterPasswords(tester, 'short', 'short', 'Continue');
      await shot(tester, 'onb_07_too_short');
      await enterPasswords(tester, 'correct horse battery', 'correct horse batterz', 'Continue');
      await shot(tester, 'onb_07_mismatch');
      server.rejectPassword = true;
      await enterPasswords(tester, 'correct horse battery', 'correct horse battery', 'Continue');
      await shot(tester, 'onb_07_server_rejected');
      server.rejectPassword = false;
      await enterPasswords(tester, 'correct horse battery', 'correct horse battery', 'Continue');
      await shot(tester, 'onb_08_ready');
      await tapText(tester, 'Start Jitan');
      await shot(tester, 'home');
    });

    for (final (name, arrange, qr) in <(String, void Function(FakeJitanServer), String)>[
      ('err_01_invalid_qr', (_) {}, terminalQr),
      ('err_02_already_activated', (s) => s.password = 'set earlier', testQr),
      ('err_03_account_unavailable', (s) => s.active = false, testQr),
      ('err_06_server_unavailable', (s) => s.dropNext.add('/onboarding/start'), testQr),
      ('err_qr_expired_or_used', (s) => s.expiredQrs.add(testQr), testQr),
      ('err_wrong_qr', (_) {}, recoveryQr),
    ]) {
      testWidgets('onboarding error on scan: $name', (tester) async {
        await start(tester, arrange: () => arrange(server));
        await toScanner(tester);
        await scan(tester, qr);
        await shot(tester, name);
      });
    }

    for (final (name, arrange) in <(String, void Function(FakeJitanServer, MemorySecureStore))>[
      ('err_04_activated_elsewhere', (s, _) => s.anotherDeviceWins = true),
      ('err_05_network_failure', (s, _) => s.dropNext.add('/onboarding/complete')),
      ('err_07_session_recovery', (_, store) => store.failWrites = true),
    ]) {
      testWidgets('onboarding error on completion: $name', (tester) async {
        await start(tester);
        await toPassword(tester);
        arrange(server, store);
        await enterPasswords(tester, 'correct horse battery', 'correct horse battery', 'Continue');
        await shot(tester, name);
      });
    }

    testWidgets('sign in and its errors', (tester) async {
      await start(tester, signedInBefore: true, arrange: () => server.password = 'correct horse battery');
      await shot(tester, 'auth_01_sign_in');
      await signIn(tester, code: 'SBW', password: 'wrong password');
      await shot(tester, 'auth_03_invalid_credentials');
      await tapText(tester, 'Try again');
      server.dropNext.add('/auth/sign-in');
      await signIn(tester, password: 'correct horse battery');
      await shot(tester, 'auth_05_network_error');
      await tapText(tester, 'Try again');
      await shot(tester, 'profile_home_after_sign_in');
      await tester.tap(find.byTooltip('Profile'));
      await settle(tester);
      await shot(tester, 'profile_employee');
      await tapText(tester, 'Password & web login');
      await shot(tester, 'profile_password');
      await tapText(tester, 'Change password');
      await shot(tester, 'profile_change_password');
    });

    testWidgets('account unavailable', (tester) async {
      await start(tester, signedInBefore: true, arrange: () {
        server
          ..password = 'correct horse battery'
          ..active = false;
      });
      await signIn(tester, code: 'SBW', password: 'correct horse battery');
      await shot(tester, 'auth_04_account_unavailable');
    });

    testWidgets('forgot password and recovery', (tester) async {
      await start(tester, signedInBefore: true, arrange: () => server.password = 'correct horse battery');
      await tapText(tester, 'Forgot password?');
      await shot(tester, 'auth_02_forgot_password');
      await tapText(tester, 'Back to sign in');
      await tapText(tester, 'Scan QR to recover account');
      await shot(tester, 'auth_06_recover');
      await scan(tester, recoveryQr);
      await shot(tester, 'auth_06B_recovery_refused');
      server
        ..password = null
        ..expiredQrs.add(recoveryQr);
      await tapText(tester, 'Back');
      await tapText(tester, 'Scan QR to recover account');
      await scan(tester, recoveryQr);
      await shot(tester, 'auth_06C_qr_expired');
      server.expiredQrs.clear();
      await tapText(tester, 'Back');
      await tapText(tester, 'Scan QR to recover account');
      await scan(tester, recoveryQr);
      await shot(tester, 'auth_07_set_new_password');
    });
  });
}

/// Lets requests, state changes and screen transitions finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
