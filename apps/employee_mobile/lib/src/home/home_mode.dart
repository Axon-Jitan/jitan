import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import '../geofencing/workplace_presence.dart';

/// What Home offers for registering (product owner, 2026-11-12): Jitan
/// doesn't ask for what it already knows.
enum HomeMode {
  /// Location registers the day: no main button, only a quiet link to do it
  /// by hand.
  automatic,

  /// The employee scans at a Jitan Terminal: "Show my QR", and a quiet link
  /// to use the app instead.
  qr,

  /// "Start work" and "Finish work".
  manual,
}

/// The employee's method as it works on this phone. Automatic without
/// location access, or with the geofences refused, can't register anything,
/// so Home offers the buttons until it can.
Future<HomeMode> homeModeOf(DeviceSettings settings, PermissionsGateway permissions, WorkplacePresence presence) async {
  switch (await settings.registrationMethod()) {
    case RegistrationMethod.qr:
      return HomeMode.qr;
    case RegistrationMethod.automatic:
      final access = await permissions.locationAccess();
      return access.always && !await presence.geofencesRefused() ? HomeMode.automatic : HomeMode.manual;
    case RegistrationMethod.manual || null:
      return HomeMode.manual;
  }
}
