import 'package:flutter/widgets.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:logging/logging.dart';
import 'package:native_geofence/native_geofence.dart';

import '../config/employee_config.dart';
import '../device/secure_store.dart';
import '../device/session_manager.dart';
import 'away_reminder.dart';
import 'geofence_event_handler.dart';
import 'location_watcher.dart';
import 'workplace_presence.dart';

/// Called by the system on a geofence event, also when the app is closed, in
/// its own isolate: nothing from the app is in memory, so everything is built
/// here from the stored session. Signed out, the event is ignored.
@pragma('vm:entry-point')
Future<void> onGeofenceEvent(GeofenceCallbackParams params) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = EmployeeConfig.fromEnvironment();
  if (config == null) return;
  const store = PlatformSecureStore();
  final session = SessionManager(store);
  if (!await session.restore()) return;
  final handler = GeofenceEventHandler(
    api: TimeRegistrationsApi(ApiTransport(baseUri: config.apiBaseUri, accessToken: () => session.accessToken)),
    presence: const WorkplacePresence(store),
    reminder: LocalAwayReminder(),
  );
  final change = switch (params.event) {
    GeofenceEvent.enter => GeofenceChange.entered,
    GeofenceEvent.dwell => GeofenceChange.stayed,
    GeofenceEvent.exit => GeofenceChange.left,
  };
  for (final geofence in params.geofences) {
    final addressId = NativeLocationWatcher.addressIdOf(geofence.id);
    if (addressId == null) {
      Logger('geofencing').warning('Ignored an unknown geofence.');
      continue;
    }
    await handler.handle(change, addressId);
  }
}
