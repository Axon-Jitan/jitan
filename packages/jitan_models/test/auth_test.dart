import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('sign-in request round-trips and never prints the password', () {
    const request = SignInRequest(code: 'SBW', password: 'correct horse', deviceId: 'device-1234567890ab');

    expect(SignInRequest.fromJson(request.toJson()).toJson(), request.toJson());
    expect('$request', isNot(contains('correct horse')));
  });

  test('change-password request round-trips and never prints the password', () {
    const request = ChangePasswordRequest(newPassword: 'new secret pass');

    expect(ChangePasswordRequest.fromJson(request.toJson()).newPassword, 'new secret pass');
    expect('$request', isNot(contains('new secret pass')));
  });

  test('missing fields are format errors', () {
    expect(() => SignInRequest.fromJson({'code': 'SBW'}), throwsFormatException);
    expect(() => ChangePasswordRequest.fromJson({}), throwsFormatException);
  });
}
