import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('EmployeeListResponse round-trips, including null names and several groups', () {
    const original = EmployeeListResponse(
      companyId: 7,
      employees: [
        EmployeeSummary(
          id: 1,
          firstName: 'Disan',
          lastName: 'Ssebowa',
          code: 'SBW',
          groups: ['White collar'],
          isActive: true,
          isActivated: false,
        ),
        EmployeeSummary(
          id: 2,
          firstName: null,
          lastName: null,
          code: 'X1',
          groups: ['A', 'B'],
          isActive: false,
          isActivated: false,
        ),
      ],
    );

    final decoded = EmployeeListResponse.fromJson(original.toJson());

    expect(decoded.companyId, 7);
    expect(decoded.employees.first.code, 'SBW');
    expect(decoded.employees.first.groups, ['White collar']);
    expect(decoded.employees.last.firstName, isNull);
    expect(decoded.employees.last.groups, ['A', 'B']);
    expect(decoded.employees.last.isActive, isFalse);
  });

  test('rejects groups that are not strings', () {
    expect(
      () => EmployeeSummary.fromJson({
        'id': 1,
        'firstName': 'A',
        'lastName': 'B',
        'code': 'C',
        'groups': [1],
        'isActive': true,
      }),
      throwsFormatException,
    );
  });
}
