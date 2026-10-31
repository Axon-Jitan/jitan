import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'src/app/employee_app.dart';
import 'src/app/employee_services.dart';
import 'src/config/employee_config.dart';
import 'src/device/device_settings.dart';
import 'src/device/permissions_gateway.dart';
import 'src/device/secure_store.dart';
import 'src/device/session_manager.dart';
import 'src/geofencing/automatic_registration.dart';
import 'src/geofencing/location_watcher.dart';
import 'src/geofencing/workplace_presence.dart';
import 'src/l10n/employee_text_keys.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerJitanFontLicenses();
  // A phone app held upright: the screens are designed for portrait.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final config = EmployeeConfig.fromEnvironment();
  if (config == null) {
    runApp(const _ConfigurationErrorApp());
    return;
  }

  const store = PlatformSecureStore();
  final session = SessionManager(store);
  final transport = ApiTransport(baseUri: config.apiBaseUri, accessToken: () => session.accessToken);
  final languagesApi = LanguagesApi(transport);
  final locationsApi = LocationsApi(transport);
  const presence = WorkplacePresence(store);
  runApp(
    EmployeeApp(
      services: EmployeeServices(
        onboardingApi: OnboardingApi(transport),
        recoveryApi: RecoveryApi(transport),
        authApi: AuthApi(transport),
        languagesApi: languagesApi,
        meApi: MeApi(transport),
        timeRegistrationsApi: TimeRegistrationsApi(transport),
        locationsApi: locationsApi,
        presence: presence,
        automaticRegistration: AutomaticRegistration(
          settings: const DeviceSettings(store),
          permissions: const PlatformPermissionsGateway(),
          locations: locationsApi,
          watcher: const NativeLocationWatcher(),
          presence: presence,
        ),
        translationService: TranslationService(languagesApi),
        session: session,
        settings: const DeviceSettings(store),
        permissions: const PlatformPermissionsGateway(),
      ),
    ),
  );
}

/// Shown when the build lacks `JITAN_API_BASE_URL`.
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) => TranslationScope(
    translations: Translations.english(),
    child: Builder(
      builder: (context) => MaterialApp(
        theme: JitanTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: JitanErrorState(
                title: context.t(EmployeeTextKeys.configErrorTitle),
                message: context.t(EmployeeTextKeys.configErrorMessage),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
