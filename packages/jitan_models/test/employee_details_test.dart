import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('EmployeeDetails round-trips, with nullable names and phone', () {
    const original = EmployeeDetails(
      id: 1,
      companyId: 7,
      companyName: 'Almeco',
      firstName: 'Disan',
      lastName: null,
      code: 'SBW',
      groups: ['White collar'],
      phone: null,
      isActive: true,
      isActivated: false,
    );

    final decoded = EmployeeDetails.fromJson(original.toJson());

    expect(decoded.companyName, 'Almeco');
    expect(decoded.lastName, isNull);
    expect(decoded.phone, isNull);
    expect(decoded.groups, ['White collar']);
  });

  test('never carries secrets', () {
    const details = EmployeeDetails(
      id: 1,
      companyId: 7,
      companyName: 'A',
      firstName: 'B',
      lastName: 'C',
      code: 'D',
      groups: [],
      phone: null,
      isActive: true,
      isActivated: false,
    );

    expect(details.toJson().keys, isNot(anyOf(contains('password'), contains('pin'), contains('qr'))));
  });

  test('accessResetPending round-trips and defaults to false for older payloads', () {
    const details = EmployeeDetails(
      id: 1,
      companyId: 7,
      companyName: 'Almeco',
      firstName: null,
      lastName: null,
      code: 'SBW',
      groups: [],
      phone: null,
      isActive: true,
      isActivated: false,
      accessResetPending: true,
    );

    expect(EmployeeDetails.fromJson(details.toJson()).accessResetPending, isTrue);
    expect(EmployeeDetails.fromJson({...details.toJson()}..remove('accessResetPending')).accessResetPending, isFalse);
  });
}
