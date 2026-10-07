import '../http/api_exception.dart';

/// The app's random per-install device id (sent with onboarding and sign-in,
/// carried in the session token). URL-safe base64-like, 16–128 characters.
final _deviceIdFormat = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// [deviceId] when well-formed; otherwise a validation error on [field].
String checkedDeviceId(String deviceId, {required String field}) {
  if (!_deviceIdFormat.hasMatch(deviceId)) throw ApiException.validation(field, 'Invalid device identifier.');
  return deviceId;
}
