import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('onboarding requests round-trip and never print secrets', () {
    const start = OnboardingStartRequest(qrCode: 'SECRET');
    const complete = OnboardingCompleteRequest(qrCode: 'SECRET', password: 'p4ssword!');

    expect(OnboardingStartRequest.fromJson(start.toJson()).qrCode, 'SECRET');
    expect(OnboardingCompleteRequest.fromJson(complete.toJson()).password, 'p4ssword!');
    expect('$start $complete', isNot(contains('SECRET')));
    expect('$complete', isNot(contains('p4ssword')));
  });

  test('OnboardingAccount round-trips', () {
    const account = OnboardingAccount(firstName: 'Disan', lastName: null, code: 'SBW', companies: ['Almeco', 'PCA']);

    final decoded = OnboardingAccount.fromJson(account.toJson());

    expect(decoded.code, 'SBW');
    expect(decoded.lastName, isNull);
    expect(decoded.companies, ['Almeco', 'PCA']);
  });
}
