import 'package:permission_handler/permission_handler.dart';

/// What the phone currently allows, without asking.
typedef LocationAccess = ({bool whileInUse, bool always});

/// Asks the operating system for the permissions Jitan needs. Each method
/// shows the system prompt when needed and returns whether it is granted.
abstract interface class PermissionsGateway {
  /// Location while the app is in use.
  Future<bool> requestLocation();

  /// Location with the app closed, for automatic registration. Android asks
  /// this after [requestLocation] was granted.
  Future<bool> requestBackgroundLocation();

  Future<bool> requestNotifications();

  Future<LocationAccess> locationAccess();

  /// Opens this app's page in the phone's settings.
  Future<void> openSettings();
}

class PlatformPermissionsGateway implements PermissionsGateway {
  const PlatformPermissionsGateway();

  @override
  Future<bool> requestLocation() async => (await Permission.locationWhenInUse.request()).isGranted;

  @override
  Future<bool> requestBackgroundLocation() async => (await Permission.locationAlways.request()).isGranted;

  @override
  Future<bool> requestNotifications() async => (await Permission.notification.request()).isGranted;

  @override
  Future<LocationAccess> locationAccess() async =>
      (whileInUse: await Permission.locationWhenInUse.isGranted, always: await Permission.locationAlways.isGranted);

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
