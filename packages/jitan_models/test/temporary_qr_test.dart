import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('temporary QR response round-trips with purpose and UTC expiry, and redacts itself', () {
    final response = TemporaryQrResponse(
      qrCode: 'signed-token',
      purpose: TemporaryQrPurpose.recovery,
      expiresAt: DateTime.utc(2026, 10, 8, 12, 10),
    );

    final back = TemporaryQrResponse.fromJson(response.toJson());

    expect((back.qrCode, back.purpose, back.expiresAt), ('signed-token', TemporaryQrPurpose.recovery, DateTime.utc(2026, 10, 8, 12, 10)));
    expect(response.toString(), isNot(contains('signed-token')));
    expect(() => TemporaryQrResponse.fromJson({...response.toJson(), 'purpose': 'sign-in'}), throwsFormatException);
  });

  test('recovery requests carry the QR and never print it', () {
    const complete = RecoveryCompleteRequest(qrCode: 'tok', password: 'secret-pass', deviceId: 'dev');

    final back = RecoveryCompleteRequest.fromJson(complete.toJson());

    expect((back.qrCode, back.password, back.deviceId), ('tok', 'secret-pass', 'dev'));
    expect(complete.toString(), isNot(contains('secret-pass')));
    expect(RecoveryStartRequest.fromJson({'qrCode': 'tok'}).qrCode, 'tok');
    expect(TemporaryQrPurpose.fromWire('onboarding'), TemporaryQrPurpose.onboarding);
  });
}
