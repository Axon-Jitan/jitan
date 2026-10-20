import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  const monday = ScheduleDay(id: 1, name: 'Monday', weekday: 1);

  test('a group schedule round-trips, with missing parts kept as null', () {
    const schedule = GroupSchedule(
      group: GroupSummary(id: 2, name: 'Blue collar'),
      status: GroupScheduleStatus.employeesDiffer,
      singleGroupEmployeeCount: 3,
      variants: [
        ScheduleVariant(
          employeeCount: 2,
          favour: ScheduleRoundingFavour.employee,
          workDays: [
            WorkDaySchedule(
              day: monday,
              start: WorkBoundary(time: '08:00', toleranceMinutes: 5, rounding: ScheduleRounding(intervalMinutes: 30, roundUp: false)),
            ),
          ],
          breaks: [BreakSchedule(day: monday, usualStart: '12:00', lengthMinutes: 45)],
        ),
        ScheduleVariant(employeeCount: 1, workDays: [], breaks: []),
      ],
    );

    final back = GroupSchedule.fromJson(schedule.toJson());

    expect((back.group.name, back.status, back.singleGroupEmployeeCount), ('Blue collar', GroupScheduleStatus.employeesDiffer, 3));
    final first = back.variants.first;
    expect(first.favour, ScheduleRoundingFavour.employee);
    expect(first.workDays.single.start!.rounding!.intervalMinutes, 30);
    expect(first.workDays.single.finish, isNull);
    expect(first.breaks.single.usualStart, '12:00');
    expect(back.variants.last.favour, isNull);
  });

  test('options round-trip', () {
    const options = ScheduleOptions(
      days: [monday],
      roundingIntervalMinutes: [15, 30, 60],
      toleranceMinutes: [0, 5, 10, 15],
      breakLengthMinutes: [15, 30, 45, 60],
    );

    final back = ScheduleOptions.fromJson(options.toJson());

    expect(back.days.single.name, 'Monday');
    expect(back.roundingIntervalMinutes, [15, 30, 60]);
    expect(back.breakLengthMinutes, [15, 30, 45, 60]);
  });

  test('an unknown status is rejected, not guessed', () {
    final json = const GroupSchedule(
      group: GroupSummary(id: 1, name: 'x'),
      status: GroupScheduleStatus.configured,
      singleGroupEmployeeCount: 0,
      variants: [],
    ).toJson()
      ..['status'] = 'somethingElse';

    expect(() => GroupSchedule.fromJson(json), throwsArgumentError);
  });
}
