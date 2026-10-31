import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:logging/logging.dart';

import '../device/device_settings.dart';
import '../device/permissions_gateway.dart';
import 'geofence_event_handler.dart';
import 'location_watcher.dart';
import 'workplace_presence.dart';

final _log = Logger('geofencing');

/// Turns detection on or off for the method the employee chose, each time
/// the app opens. Only an employee on Automatic is ever watched, and only
/// with their permission (D30).
class AutomaticRegistration {
  const AutomaticRegistration({
    required this._settings,
    required this._permissions,
    required this._locations,
    required this._watcher,
    required this._presence,
    required this._events,
  });

  final DeviceSettings _settings;
  final PermissionsGateway _permissions;
  final LocationsApi _locations;
  final LocationWatcher _watcher;
  final WorkplacePresence _presence;
  final GeofenceEventHandler _events;

  /// The app is open: an arrival the system did not finish reporting.
  Future<void> catchUp() => _events.catchUp();

  Future<void> start() async {
    try {
      if (await _settings.registrationMethod() != RegistrationMethod.automatic) return await _watcher.stop();
      if (!await _permissions.requestLocation() || !await _permissions.requestBackgroundLocation()) return;
      final locations = await _locations.recognised();
      await _presence.saveNames(locations);
      await _presence.setGeofencesRefused(!await _watcher.watch(locations));
      await _events.catchUp();
    } on ApiClientException catch (e) {
      // The geofences already on the phone keep working; tried again next time.
      _log.warning('Locations could not be loaded: ${e.kind.name} ${e.statusCode ?? ''}');
    }
  }
}
