import 'secure_store.dart';

/// How the employee registers time (onboarding step 5).
enum RegistrationMethod {
  /// Geofence-based: needs location permission.
  automatic,

  /// QR at a Jitan Terminal, or manual entry.
  manual,
}

/// Settings that belong to this device only.
///
/// ERD GAP-07: the ERD has no field for the registration method, so the
/// choice lives on the device until IT decides where it belongs.
class DeviceSettings {
  const DeviceSettings(this._store);

  final SecureStore _store;

  static const _methodKey = 'settings.registrationMethod';

  Future<RegistrationMethod?> registrationMethod() async {
    final stored = await _store.read(_methodKey);
    return RegistrationMethod.values.where((m) => m.name == stored).firstOrNull;
  }

  Future<void> setRegistrationMethod(RegistrationMethod method) => _store.write(_methodKey, method.name);
}
