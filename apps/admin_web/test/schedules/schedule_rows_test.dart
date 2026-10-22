import 'package:admin_web/src/schedules/schedule_rows.dart';
import 'package:admin_web/src/schedules/schedule_summary_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_schedules_api.dart';

void main() {
  final t = Translations.english();

  group('rows', () {
    test('one row per group with a schedule (1458:2); groups without a schedule have none', () {
      final rows = scheduleRowsOf([
        groupSchedule(1, 'Blue collar', work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'), breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30)),
        groupSchedule(2, 'White collar', work: workDays([1], '09:00', '17:00')),
        groupSchedule(3, 'New', status: GroupScheduleStatus.noSchedule),
        groupSchedule(4, 'Mixed only', status: GroupScheduleStatus.noSingleGroupEmployees),
      ]);

      expect([for (final r in rows) (r.group.name, r.hasWorkHours, r.hasBreaks, r.status)], [
        ('Blue collar', true, true, ScheduleRowStatus.active),
        ('White collar', true, false, ScheduleRowStatus.active),
      ]);
    });

    test('when the employees differ, the row says so and shows no variant', () {
      final rows = scheduleRowsOf([
        groupSchedule(
          1,
          'Blue collar',
          status: GroupScheduleStatus.employeesDiffer,
          variants: [
            ScheduleVariant(employeeCount: 2, workDays: workDays([1], '08:00', '16:00'), breaks: const []),
            ScheduleVariant(employeeCount: 1, workDays: workDays([1], '07:00', '15:00'), breaks: const []),
          ],
        ),
      ]);

      expect(rows.single.status, ScheduleRowStatus.employeesDiffer);
      expect(rows.single.variant, isNull);
    });

    test('filters combine; search matches the group name ignoring case', () {
      final rows = scheduleRowsOf([
        groupSchedule(1, 'Blue collar', work: workDays([1], '08:00', '16:30'), breakDays: breaks([1], '12:00', 30)),
        groupSchedule(2, 'White collar', work: workDays([1], '09:00', '17:00')),
      ]);
      List<String> names(ScheduleFilter f) => [for (final r in rows.where(f.matches)) r.group.name];

      expect(names(const ScheduleFilter(search: 'BLUE')), ['Blue collar']);
      expect(names(const ScheduleFilter(groupId: 2)), ['White collar']);
      expect(names(const ScheduleFilter(groupId: 2, status: ScheduleRowStatus.employeesDiffer)), isEmpty);
      expect(names(const ScheduleFilter(status: ScheduleRowStatus.active)), ['Blue collar', 'White collar']);
    });
  });

  group('summaries', () {
    test('work hours: consecutive days with the same hours become a range', () {
      final variant = ScheduleVariant(
        employeeCount: 3,
        workDays: [...workDays([1, 2, 3, 4], '08:00', '16:30'), ...workDays([5], '08:00', '12:00')],
        breaks: const [],
      );

      expect(
        workHoursSummary(t, variant),
        'Mon–Thu 08:00–16:30, Fri 08:00–12:00 · ±5 min · Start: Up, every 15 min · Finish: Down, every 15 min',
      );
    });

    test('work hours: different tolerances and no rounding', () {
      final variant = ScheduleVariant(
        employeeCount: 1,
        workDays: [
          for (final weekday in [1, 3])
            WorkDaySchedule(
              day: testDay(weekday),
              start: const WorkBoundary(time: '07:00', toleranceMinutes: 10),
              finish: const WorkBoundary(time: '15:00', toleranceMinutes: 0),
            ),
        ],
        breaks: const [],
      );

      expect(workHoursSummary(t, variant), 'Mon, Wed 07:00–15:00 · +10 / −0 min · No rounding');
    });

    test('breaks', () {
      final variant = ScheduleVariant(
        employeeCount: 3,
        workDays: const [],
        breaks: [...breaks([1, 2, 3, 4, 5], '12:00', 30), ...breaks([6, 7], '11:00', 15)],
      );

      expect(breaksSummary(t, variant), 'Mon–Fri · 30 min, Sat, Sun · 15 min');
    });
  });
}
