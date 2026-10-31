import 'package:jitan_models/jitan_models.dart' as jitan;
import 'package:native_geofence/native_geofence.dart';

import 'geofence_background.dart';
import 'geofence_event_handler.dart';

/// Keeps the phone's geofences equal to the recognised locations. The only
/// place that knows the geofencing plugin, with [onGeofenceEvent].
abstract interface class LocationWatcher {
  Future<void> watch(List<jitan.Location> locations);

  /// Stops all detection (the employee is on QR / manual).
  Future<void> stop();
}

class NativeLocationWatcher implements LocationWatcher {
  const NativeLocationWatcher();

  static const _prefix = 'location-';

  static String idOf(int addressId) => '$_prefix$addressId';

  /// The location of a geofence id; `null` for anything else.
  static int? addressIdOf(String id) => id.startsWith(_prefix) ? int.tryParse(id.substring(_prefix.length)) : null;

  Geofence _geofence(jitan.Location location) => Geofence(
    id: idOf(location.id),
    location: Location(latitude: location.point!.latitude, longitude: location.point!.longitude),
    radiusMeters: location.radiusMeters.toDouble(),
    triggers: {GeofenceEvent.enter, GeofenceEvent.dwell, GeofenceEvent.exit},
    // Already inside when the geofence is added counts as entering.
    iosSettings: const IosGeofenceSettings(initialTrigger: true),
    androidSettings: const AndroidGeofenceSettings(
      initialTriggers: {GeofenceEvent.enter},
      loiteringDelay: GeofenceEventHandler.arrivalDelay,
    ),
  );

  static bool _same(ActiveGeofence active, Geofence wanted) =>
      active.radiusMeters == wanted.radiusMeters &&
      active.location.latitude == wanted.location.latitude &&
      active.location.longitude == wanted.location.longitude;

  @override
  Future<void> watch(List<jitan.Location> locations) async {
    await NativeGeofenceManager.instance.initialize();
    final wanted = {for (final location in locations) idOf(location.id): _geofence(location)};
    final active = await NativeGeofenceManager.instance.getRegisteredGeofences();
    for (final geofence in active) {
      final next = wanted[geofence.id];
      if (next == null || !_same(geofence, next)) {
        await NativeGeofenceManager.instance.removeGeofenceById(geofence.id);
      } else {
        wanted.remove(geofence.id);
      }
    }
    for (final geofence in wanted.values) {
      await NativeGeofenceManager.instance.createGeofence(geofence, onGeofenceEvent);
    }
  }

  @override
  Future<void> stop() async {
    await NativeGeofenceManager.instance.initialize();
    await NativeGeofenceManager.instance.removeAllGeofences();
  }
}
