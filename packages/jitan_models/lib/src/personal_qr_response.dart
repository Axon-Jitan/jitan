import 'json_reading.dart';

/// Response of `POST /companies/{companyId}/employees/{userId}/onboarding-qr`.
///
/// [qrCode] is `tblUser.userQRcode`: the value encoded in the QR the employee
/// scans to onboard, which stays their personal QR for Jitan Terminal
/// afterwards (IT decision, 2026-10-07). It is a credential: show it only
/// where needed, never log it.
class PersonalQrResponse {
  const PersonalQrResponse({required this.qrCode});

  factory PersonalQrResponse.fromJson(Map<String, Object?> json) =>
      PersonalQrResponse(qrCode: json.readString('qrCode'));

  final String qrCode;

  Map<String, Object?> toJson() => {'qrCode': qrCode};

  /// Redacted: the value is a credential.
  @override
  String toString() => 'PersonalQrResponse(qrCode: <redacted>)';
}
