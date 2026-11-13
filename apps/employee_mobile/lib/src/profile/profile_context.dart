import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../device/session_manager.dart';
import '../geofencing/workplace_presence.dart';

/// What the Profile pages need from the app.
class ProfileContext {
  const ProfileContext({
    required this.account,
    required this.meApi,
    required this.languagesApi,
    required this.session,
    required this.settings,
    required this.permissions,
    required this.onMethodChanged,
    required this.onLanguageChanged,
    required this.presence,
    required this.onSignOut,
    required this.onSessionEnded,
  });

  final EmployeeAccount? account;
  final MeApi meApi;
  final LanguagesApi languagesApi;
  final SessionManager session;
  final DeviceSettings settings;
  final PermissionsGateway permissions;

  /// The registration method changed: detection follows it.
  final Future<void> Function() onMethodChanged;

  /// The server saved a new language: the app shows it.
  final Future<void> Function(String languageCode) onLanguageChanged;
  final WorkplacePresence presence;

  /// Confirmed "Sign out".
  final void Function() onSignOut;

  /// The server no longer accepts this device's session.
  final void Function() onSessionEnded;
}
