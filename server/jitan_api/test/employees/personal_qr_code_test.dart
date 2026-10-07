import 'package:jitan_api/src/employees/personal_qr_code.dart';
import 'package:test/test.dart';

void main() {
  test('24 URL-safe characters', () {
    final code = newPersonalQrCode();

    expect(code, hasLength(24));
    expect(code, matches(RegExp(r'^[A-Za-z0-9_-]{24}$')));
  });

  test('values do not repeat', () {
    final codes = {for (var i = 0; i < 1000; i++) newPersonalQrCode()};

    expect(codes, hasLength(1000));
  });
}
