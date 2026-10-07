import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('onboarding requests round-trip and never print secrets', () {
    const start = OnboardingStartRequest(qrCode: 'SECRET');
    const complete = OnboardingCompleteRequest(
      qrCode: 'SECRET',
      password: 'p4ssword!',
      deviceId: 'device-1234567890',
      languageCode: 'nl',
    );

    expect(OnboardingStartRequest.fromJson(start.toJson()).qrCode, 'SECRET');
    final decoded = OnboardingCompleteRequest.fromJson(complete.toJson());
    expect(decoded.password, 'p4ssword!');
    expect(decoded.deviceId, 'device-1234567890');
    expect(decoded.languageCode, 'nl');
    expect('$start $complete', isNot(contains('SECRET')));
    expect('$complete', isNot(contains('p4ssword')));
  });

  test('EmployeeAccount round-trips', () {
    const account = EmployeeAccount(firstName: 'Disan', lastName: null, code: 'SBW', companies: ['Almeco', 'PCA']);

    final decoded = EmployeeAccount.fromJson(account.toJson());

    expect(decoded.code, 'SBW');
    expect(decoded.lastName, isNull);
    expect(decoded.companies, ['Almeco', 'PCA']);
  });

  test('OnboardingCompleteResponse carries the session; printing it hides the token', () {
    final response = OnboardingCompleteResponse(
      account: const EmployeeAccount(firstName: 'A', lastName: 'B', code: 'C', companies: []),
      session: SessionInfo(accessToken: 'TOKEN.VALUE.SIG', expiresAt: DateTime.utc(2026, 11, 6)),
    );

    final decoded = OnboardingCompleteResponse.fromJson(response.toJson());

    expect(decoded.session.accessToken, 'TOKEN.VALUE.SIG');
    expect(decoded.session.expiresAt, DateTime.utc(2026, 11, 6));
    expect('$response ${response.session}', isNot(contains('TOKEN')));
  });
}
