import 'json_reading.dart';

/// Body of `POST /onboarding/start`: the scanned temporary onboarding QR
/// (never the permanent Terminal QR).
class OnboardingStartRequest {
  const OnboardingStartRequest({required this.qrCode});

  factory OnboardingStartRequest.fromJson(Map<String, Object?> json) =>
      OnboardingStartRequest(qrCode: json.readString('qrCode'));

  final String qrCode;

  Map<String, Object?> toJson() => {'qrCode': qrCode};

  @override
  String toString() => 'OnboardingStartRequest(qrCode: <redacted>)';
}

/// Body of `POST /onboarding/complete`. Setting a password is mandatory:
/// storing it is what completes onboarding. The response signs the device in.
class OnboardingCompleteRequest {
  const OnboardingCompleteRequest({
    required this.qrCode,
    required this.password,
    required this.deviceId,
    this.languageCode,
  });

  factory OnboardingCompleteRequest.fromJson(Map<String, Object?> json) => OnboardingCompleteRequest(
        qrCode: json.readString('qrCode'),
        password: json.readString('password'),
        deviceId: json.readString('deviceId'),
        languageCode: json.readOptionalString('languageCode'),
      );

  final String qrCode;
  final String password;

  /// Random identifier the app generated for this installation and keeps in
  /// secure storage.
  final String deviceId;

  /// The language chosen during onboarding (`tblLanguage.languageCode`);
  /// `null` keeps the default (English).
  final String? languageCode;

  /// Field names for [ApiError.field].
  static const fieldPassword = 'password';
  static const fieldDeviceId = 'deviceId';
  static const fieldLanguageCode = 'languageCode';

  Map<String, Object?> toJson() => {
        'qrCode': qrCode,
        'password': password,
        'deviceId': deviceId,
        'languageCode': languageCode,
      };

  @override
  String toString() => 'OnboardingCompleteRequest(<redacted>)';
}

/// Who an employee is, for display: the onboarding confirmation ("Is this
/// you?") and the signed-in app (`GET /me`). No IDs, no QR, no password.
class EmployeeAccount {
  const EmployeeAccount({
    required this.firstName,
    required this.lastName,
    required this.code,
    required this.companies,
  });

  factory EmployeeAccount.fromJson(Map<String, Object?> json) => EmployeeAccount(
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        code: json.readString('code'),
        companies: json.readStringList('companies'),
      );

  final String? firstName;
  final String? lastName;

  /// Employee code, the sign-in identity.
  final String code;

  /// Names of the employee's (non-deleted) companies.
  final List<String> companies;

  Map<String, Object?> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'companies': companies,
      };
}

/// An authenticated session for one device.
class SessionInfo {
  const SessionInfo({required this.accessToken, required this.expiresAt});

  factory SessionInfo.fromJson(Map<String, Object?> json) => SessionInfo(
        accessToken: json.readString('accessToken'),
        expiresAt: json.readOptionalDateTime('expiresAt') ??
            (throw const FormatException('Expected "expiresAt" to be a date-time.')),
      );

  /// Sent as `Authorization: Bearer <accessToken>`. Keep in secure storage.
  final String accessToken;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {'accessToken': accessToken, 'expiresAt': expiresAt.toUtc().toIso8601String()};

  @override
  String toString() => 'SessionInfo(<redacted>, expires $expiresAt)';
}

/// A signed-in device: the account and its session. Returned by
/// `POST /onboarding/complete` (onboarding signs the device in, no second
/// sign-in step), `POST /auth/sign-in` and `POST /me/password`.
class SessionResponse {
  const SessionResponse({required this.account, required this.session});

  factory SessionResponse.fromJson(Map<String, Object?> json) => SessionResponse(
        account: EmployeeAccount.fromJson(json.readObject('account')),
        session: SessionInfo.fromJson(json.readObject('session')),
      );

  final EmployeeAccount account;
  final SessionInfo session;

  Map<String, Object?> toJson() => {'account': account.toJson(), 'session': session.toJson()};

  @override
  String toString() => 'SessionResponse(${account.code}, <session redacted>)';
}
