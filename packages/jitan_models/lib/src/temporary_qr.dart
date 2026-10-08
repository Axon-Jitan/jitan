import 'json_reading.dart';

/// What a temporary QR may be used for (IT decision 2026-10-08). A token is
/// never accepted for another purpose.
enum TemporaryQrPurpose {
  /// First setup on the employee app.
  onboarding('onboarding'),

  /// Setting a new password after HR/Admin "Reset account access".
  recovery('recovery');

  const TemporaryQrPurpose(this.wireName);

  final String wireName;

  static TemporaryQrPurpose? fromWire(String? value) =>
      TemporaryQrPurpose.values.where((p) => p.wireName == value).firstOrNull;
}

/// Response of `POST /companies/{companyId}/employees/{userId}/onboarding-qr`
/// and `…/recovery-qr`: a temporary QR for HR/Admin to show.
///
/// [qrCode] is a signed, single-use token that expires at [expiresAt] (UTC,
/// 10 minutes after issue). Generating another one invalidates it. It is a
/// credential: show it only as a QR, never log it.
class TemporaryQrResponse {
  const TemporaryQrResponse({required this.qrCode, required this.purpose, required this.expiresAt});

  factory TemporaryQrResponse.fromJson(Map<String, Object?> json) => TemporaryQrResponse(
        qrCode: json.readString('qrCode'),
        purpose: TemporaryQrPurpose.fromWire(json.readString('purpose')) ??
            (throw const FormatException('Unknown "purpose".')),
        expiresAt: json.readOptionalDateTime('expiresAt')?.toUtc() ?? (throw const FormatException('Expected "expiresAt".')),
      );

  final String qrCode;
  final TemporaryQrPurpose purpose;
  final DateTime expiresAt;

  Map<String, Object?> toJson() => {
        'qrCode': qrCode,
        'purpose': purpose.wireName,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  @override
  String toString() => 'TemporaryQrResponse(<redacted>, ${purpose.wireName}, expires $expiresAt)';
}

/// Body of `POST /recovery/start`: the scanned temporary recovery QR.
class RecoveryStartRequest {
  const RecoveryStartRequest({required this.qrCode});

  factory RecoveryStartRequest.fromJson(Map<String, Object?> json) =>
      RecoveryStartRequest(qrCode: json.readString('qrCode'));

  final String qrCode;

  Map<String, Object?> toJson() => {'qrCode': qrCode};

  @override
  String toString() => 'RecoveryStartRequest(<redacted>)';
}

/// Body of `POST /recovery/complete`: the new password, after a recovery QR
/// was accepted. The response signs the device in.
class RecoveryCompleteRequest {
  const RecoveryCompleteRequest({required this.qrCode, required this.password, required this.deviceId});

  factory RecoveryCompleteRequest.fromJson(Map<String, Object?> json) => RecoveryCompleteRequest(
        qrCode: json.readString('qrCode'),
        password: json.readString('password'),
        deviceId: json.readString('deviceId'),
      );

  final String qrCode;
  final String password;
  final String deviceId;

  static const fieldPassword = 'password';
  static const fieldDeviceId = 'deviceId';

  Map<String, Object?> toJson() => {'qrCode': qrCode, 'password': password, 'deviceId': deviceId};

  @override
  String toString() => 'RecoveryCompleteRequest(<redacted>)';
}
