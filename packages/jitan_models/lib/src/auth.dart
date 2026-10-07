import 'json_reading.dart';

/// Body of `POST /auth/sign-in`: an activated employee signing in on a new
/// device, after a reinstall, an expired session or sign-out. Onboarding
/// never needs this: it signs the device in itself.
class SignInRequest {
  const SignInRequest({required this.code, required this.password, required this.deviceId});

  factory SignInRequest.fromJson(Map<String, Object?> json) => SignInRequest(
        code: json.readString('code'),
        password: json.readString('password'),
        deviceId: json.readString('deviceId'),
      );

  /// Employee code (`tblUser.userCode`).
  final String code;
  final String password;

  /// The app's random per-install id, as sent with onboarding.
  final String deviceId;

  static const fieldCode = 'code';
  static const fieldPassword = 'password';
  static const fieldDeviceId = 'deviceId';

  Map<String, Object?> toJson() => {'code': code, 'password': password, 'deviceId': deviceId};

  @override
  String toString() => 'SignInRequest(code: $code, password: <redacted>)';
}

/// Body of `POST /me/password`: a signed-in employee sets a new password.
/// The session proves who they are, so the current password is not needed
/// (an employee who forgot it but is still signed in can recover this way).
class ChangePasswordRequest {
  const ChangePasswordRequest({required this.newPassword});

  factory ChangePasswordRequest.fromJson(Map<String, Object?> json) =>
      ChangePasswordRequest(newPassword: json.readString('newPassword'));

  final String newPassword;

  static const fieldNewPassword = 'newPassword';

  Map<String, Object?> toJson() => {'newPassword': newPassword};

  @override
  String toString() => 'ChangePasswordRequest(<redacted>)';
}
