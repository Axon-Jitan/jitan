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

/// Body of `POST /me/password`: a signed-in employee replaces their password
/// (Figma "Profile / Change password", "Employee Web / 07B"). The current
/// password is verified server-side.
class ChangePasswordRequest {
  const ChangePasswordRequest({required this.currentPassword, required this.newPassword});

  factory ChangePasswordRequest.fromJson(Map<String, Object?> json) => ChangePasswordRequest(
        currentPassword: json.readString('currentPassword'),
        newPassword: json.readString('newPassword'),
      );

  final String currentPassword;
  final String newPassword;

  static const fieldCurrentPassword = 'currentPassword';
  static const fieldNewPassword = 'newPassword';

  Map<String, Object?> toJson() => {'currentPassword': currentPassword, 'newPassword': newPassword};

  @override
  String toString() => 'ChangePasswordRequest(<redacted>)';
}
