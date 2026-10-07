import 'package:permission_handler/permission_handler.dart';

/// Asks the operating system for the permissions Jitan needs. Each method
/// shows the system prompt when needed and returns whether it is granted.
abstract interface class PermissionsGateway {
  /// Location while the app is in use. Background location for automatic
  /// registration is requested separately, by the geofencing feature.
  Future<bool> requestLocation();

  Future<bool> requestNotifications();
}

class PlatformPermissionsGateway implements PermissionsGateway {
  const PlatformPermissionsGateway();

  @override
  Future<bool> requestLocation() async => (await Permission.locationWhenInUse.request()).isGranted;

  @override
  Future<bool> requestNotifications() async => (await Permission.notification.request()).isGranted;
}
