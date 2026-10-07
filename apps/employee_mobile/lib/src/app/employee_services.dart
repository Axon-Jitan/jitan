import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';

import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../device/session_manager.dart';
import '../onboarding/qr_scan_screen.dart';

/// Everything the Employee app talks to; replaced by fakes in tests.
class EmployeeServices {
  const EmployeeServices({
    required this.onboardingApi,
    required this.authApi,
    required this.languagesApi,
    required this.meApi,
    required this.translationService,
    required this.session,
    required this.settings,
    required this.permissions,
    this.scanQr = scanQrWithCamera,
  });

  final OnboardingApi onboardingApi;
  final AuthApi authApi;
  final LanguagesApi languagesApi;
  final MeApi meApi;
  final TranslationService translationService;
  final SessionManager session;
  final DeviceSettings settings;
  final PermissionsGateway permissions;
  final QrScanner scanQr;
}
