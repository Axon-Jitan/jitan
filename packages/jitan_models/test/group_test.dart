import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('a group overview round-trips', () {
    const list = GroupOverviewListResponse(groups: [
      GroupOverview(id: 5, name: 'Drivers', isActive: false, employeeCount: 0),
    ]);

    final back = GroupOverviewListResponse.fromJson(list.toJson()).groups.single;

    expect((back.id, back.name, back.isActive, back.employeeCount), (5, 'Drivers', false, 0));
  });

  test('the group name request carries the column limit', () {
    expect(GroupNameRequest.fromJson(const GroupNameRequest(name: 'Drivers').toJson()).name, 'Drivers');
    expect(GroupNameRequest.maxNameLength, 100);
  });

  test('Create group carries the name, the employees and the work hours', () {
    const request = CreateGroupRequest(
      name: 'Drivers',
      employeeIds: [11, 12],
      schedule: SetGroupScheduleRequest(
        workHours: SetWorkHoursRequest(
          days: [WorkHoursDay(dayId: 1, start: '08:00', finish: '16:30')],
          arrivalToleranceMinutes: 0,
          leavingToleranceMinutes: 0,
        ),
        breakMinutes: 30,
      ),
    );
    final back = CreateGroupRequest.fromJson(request.toJson());
    expect((back.name, back.schedule.breakMinutes), ('Drivers', 30));
    expect(back.employeeIds, [11, 12]);
    expect(back.schedule.workHours.days.single.finish, '16:30');
    expect(() => CreateGroupRequest.fromJson(const {'name': 'Drivers'}), throwsFormatException);
  });
}
