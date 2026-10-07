import 'json_reading.dart';

/// Body of `POST /onboarding/start`: the scanned personal QR value
/// (`tblUser.userQRcode`).
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
/// storing it is what completes onboarding.
class OnboardingCompleteRequest {
  const OnboardingCompleteRequest({required this.qrCode, required this.password});

  factory OnboardingCompleteRequest.fromJson(Map<String, Object?> json) =>
      OnboardingCompleteRequest(qrCode: json.readString('qrCode'), password: json.readString('password'));

  final String qrCode;
  final String password;

  /// Field name for [ApiError.field].
  static const fieldPassword = 'password';

  Map<String, Object?> toJson() => {'qrCode': qrCode, 'password': password};

  @override
  String toString() => 'OnboardingCompleteRequest(<redacted>)';
}

/// The account being onboarded, for the employee to confirm ("Is this
/// you?"). Response of both onboarding endpoints. Only what confirmation
/// needs: no IDs, no QR, no password.
class OnboardingAccount {
  const OnboardingAccount({
    required this.firstName,
    required this.lastName,
    required this.code,
    required this.companies,
  });

  factory OnboardingAccount.fromJson(Map<String, Object?> json) => OnboardingAccount(
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
