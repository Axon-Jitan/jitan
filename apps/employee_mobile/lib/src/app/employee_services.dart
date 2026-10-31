import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';

import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../device/session_manager.dart';
import '../geofencing/automatic_registration.dart';
import '../geofencing/workplace_presence.dart';
import '../onboarding/qr_scanner_view.dart';

/// Everything the Employee app talks to; replaced by fakes in tests.
class EmployeeServices {
  const EmployeeServices({
    required this.onboardingApi,
    required this.recoveryApi,
    required this.authApi,
    required this.languagesApi,
    required this.meApi,
    required this.timeRegistrationsApi,
    required this.locationsApi,
    required this.automaticRegistration,
    required this.presence,
    required this.translationService,
    required this.session,
    required this.settings,
    required this.permissions,
    this.qrScannerView = cameraQrScannerView,
    this.clock = DateTime.now,
  });

  final OnboardingApi onboardingApi;
  final RecoveryApi recoveryApi;
  final AuthApi authApi;
  final LanguagesApi languagesApi;
  final MeApi meApi;
  final TimeRegistrationsApi timeRegistrationsApi;
  final LocationsApi locationsApi;

  /// Turns detection on or off when the app opens.
  final AutomaticRegistration automaticRegistration;

  /// What the phone remembers about locations (Temporarily away).
  final WorkplacePresence presence;
  final TranslationService translationService;
  final SessionManager session;
  final DeviceSettings settings;
  final PermissionsGateway permissions;
  /// Embedded camera of "Scan your onboarding QR" and "Recover account".
  final QrScannerView qrScannerView;

  /// The phone's clock (the greeting, registrations made now).
  final DateTime Function() clock;
}
