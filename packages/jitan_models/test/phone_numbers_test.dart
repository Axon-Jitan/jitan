import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  group('PhoneNumbers.check', () {
    test('a number with its country code is stored in one readable form', () {
      expect(PhoneNumbers.check('+32470123456').formatted, '+32 470 12 34 56');
      expect(PhoneNumbers.check(' +32 (470) 12-34.56 ').formatted, '+32 470 12 34 56');
      expect(PhoneNumbers.check('+31612345678').formatted, '+31 6 12345678');
      expect(PhoneNumbers.check('+256772123456').formatted, '+256 772 123456');
      expect(PhoneNumbers.check('+44 20 7946 0958').formatted, '+44 20 7946 0958');
    });

    test('letters, a missing country code or an impossible number are refused', () {
      expect(PhoneNumbers.check('cbc').problem, PhoneNumberProblem.notANumber);
      expect(PhoneNumbers.check('+32abc').problem, PhoneNumberProblem.notANumber);
      expect(PhoneNumbers.check('32+470').problem, PhoneNumberProblem.notANumber);
      expect(PhoneNumbers.check('0470 12 34 56').problem, PhoneNumberProblem.missingCountryCode);
      expect(PhoneNumbers.check('+3247').problem, PhoneNumberProblem.invalid);
      expect(PhoneNumbers.check('+').problem, PhoneNumberProblem.invalid);
    });

    test('the stored form fits tblUser.cellphoneNumber', () {
      final longest = PhoneNumbers.check('+256772123456').formatted!;
      expect(longest.length, lessThanOrEqualTo(CreateEmployeeRequest.maxPhoneLength));
    });
  });

  group('PhoneNumbers.asTyped', () {
    test('keeps a leading + and digits, grouped by country as they arrive', () {
      expect(PhoneNumbers.asTyped('+'), '+');
      expect(PhoneNumbers.asTyped('+3'), '+3');
      expect(PhoneNumbers.asTyped('+32470123456'), '+32 470 12 34 56');
      expect(PhoneNumbers.asTyped('+32 47a0'), startsWith('+32 470'));
      expect(PhoneNumbers.asTyped('abc'), '');
      expect(PhoneNumbers.asTyped('0470'), '0470', reason: 'refused when checked: no country code');
    });
  });
}
