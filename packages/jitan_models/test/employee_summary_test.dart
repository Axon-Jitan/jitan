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

  test('an employee carries their hours for the Schedule column', () {
    const hours = ScheduleVariant(
      employeeCount: 1,
      workDays: [
        WorkDaySchedule(
          day: ScheduleDay(id: 1, name: 'Monday', weekday: 1),
          start: WorkBoundary(time: '08:00', toleranceMinutes: 0),
          finish: WorkBoundary(time: '16:30', toleranceMinutes: 0),
        ),
      ],
      breaks: [],
    );
    const without = EmployeeSummary(id: 1, firstName: 'A', lastName: 'B', code: 'C', groups: [], isActive: true, isActivated: false);

    final back = EmployeeSummary.fromJson(without.withSchedule(hours).toJson());
    expect(back.schedule!.workDays.single.finish!.time, '16:30');
    expect(EmployeeSummary.fromJson(without.toJson()).schedule, isNull);
  });
}
