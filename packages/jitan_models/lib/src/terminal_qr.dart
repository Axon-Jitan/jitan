import 'json_reading.dart';

/// Response of `GET /me/terminal-qr` (Figma `50:67` My QR): the employee's
/// permanent Terminal QR (`tblUser.userQRcode`), scanned at a Jitan
/// Terminal. A credential: shown only as a QR, never logged or cached. It
/// never onboards or recovers an account.
class TerminalQr {
  const TerminalQr({required this.qrCode});

  factory TerminalQr.fromJson(Map<String, Object?> json) => TerminalQr(qrCode: json.readString('qrCode'));

  final String qrCode;

  Map<String, Object?> toJson() => {'qrCode': qrCode};

  @override
  String toString() => 'TerminalQr(<redacted>)';
}
