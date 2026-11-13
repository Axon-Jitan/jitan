import '../device/permissions_gateway.dart';
import '../geofencing/workplace_presence.dart';

/// Whether automatic registration can work on this phone: location while
/// Jitan is open and while it is closed (D30), and whether the phone took
/// the workplaces (Google Location Accuracy). Profile's row and the
/// Location access page.
class LocationStatus {
  const LocationStatus({required this.whileInUse, required this.always, required this.refused});

  final bool whileInUse;
  final bool always;

  /// Allowed, but the phone refused the workplaces.
  final bool refused;

  /// Everything automatic registration needs.
  bool get allowed => whileInUse && always && !refused;

  /// Only the phone's settings stand in the way: location is allowed.
  bool get needsSettings => whileInUse && always && refused;

  static Future<LocationStatus> read(PermissionsGateway permissions, WorkplacePresence presence) async {
    final access = await permissions.locationAccess();
    return LocationStatus(whileInUse: access.whileInUse, always: access.always, refused: await presence.geofencesRefused());
  }
}
