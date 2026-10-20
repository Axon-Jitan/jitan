import 'json_reading.dart';
import 'group_summary.dart';

/// One row of `tblDays`, with the ISO weekday it stands for (1 = Monday …
/// 7 = Sunday). Clients name days with their own translation keys.
class ScheduleDay {
  const ScheduleDay({required this.id, required this.name, required this.weekday});

  factory ScheduleDay.fromJson(Map<String, Object?> json) =>
      ScheduleDay(id: json.readInt('id'), name: json.readString('name'), weekday: json.readInt('weekday'));

  final int id;

  /// `tblDays.dayName`, e.g. "Monday".
  final String name;
  final int weekday;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'weekday': weekday};
}

/// Response body of `GET /schedules/options`: the fixed choices of the
/// HR/Admin schedule form. The server validates against the same lists.
class ScheduleOptions {
  const ScheduleOptions({
    required this.days,
    required this.roundingIntervalMinutes,
    required this.toleranceMinutes,
    required this.breakLengthMinutes,
  });

  factory ScheduleOptions.fromJson(Map<String, Object?> json) => ScheduleOptions(
        days: json.readObjectList('days').map(ScheduleDay.fromJson).toList(),
        roundingIntervalMinutes: json.readIntList('roundingIntervalMinutes'),
        toleranceMinutes: json.readIntList('toleranceMinutes'),
        breakLengthMinutes: json.readIntList('breakLengthMinutes'),
      );

  /// Monday first.
  final List<ScheduleDay> days;
  final List<int> roundingIntervalMinutes;
  final List<int> toleranceMinutes;
  final List<int> breakLengthMinutes;

  Map<String, Object?> toJson() => {
        'days': [for (final day in days) day.toJson()],
        'roundingIntervalMinutes': roundingIntervalMinutes,
        'toleranceMinutes': toleranceMinutes,
        'breakLengthMinutes': breakLengthMinutes,
      };
}

/// A rounding rule (`tblRoundingRule`) of a work start or finish.
class ScheduleRounding {
  const ScheduleRounding({required this.intervalMinutes, required this.roundUp});

  factory ScheduleRounding.fromJson(Map<String, Object?> json) =>
      ScheduleRounding(intervalMinutes: json.readInt('intervalMinutes'), roundUp: json.readBool('roundUp'));

  /// `roundingRuleValueInMin`: 15, 30 or 60.
  final int intervalMinutes;

  /// `roundingRuleRoundUp`: up to the next mark, or down to the previous one.
  final bool roundUp;

  Map<String, Object?> toJson() => {'intervalMinutes': intervalMinutes, 'roundUp': roundUp};
}

/// The scheduled start or finish of a working day.
class WorkBoundary {
  const WorkBoundary({required this.time, required this.toleranceMinutes, this.rounding});

  factory WorkBoundary.fromJson(Map<String, Object?> json) => WorkBoundary(
        time: json.readString('time'),
        toleranceMinutes: json.readInt('toleranceMinutes'),
        rounding: switch (json['rounding']) {
          final Map<String, Object?> rounding => ScheduleRounding.fromJson(rounding),
          _ => null,
        },
      );

  /// Wall-clock `HH:mm`.
  final String time;

  /// `scheduleMarginMin`: minutes either side of [time].
  final int toleranceMinutes;

  /// `null` when no active rounding rule is linked (a data problem HR sees).
  final ScheduleRounding? rounding;

  Map<String, Object?> toJson() => {'time': time, 'toleranceMinutes': toleranceMinutes, 'rounding': rounding?.toJson()};
}

/// Work hours on one weekday: the "Work – start" and "Work – finish"
/// schedule rows. Either is `null` when that row is missing.
class WorkDaySchedule {
  const WorkDaySchedule({required this.day, this.start, this.finish});

  factory WorkDaySchedule.fromJson(Map<String, Object?> json) => WorkDaySchedule(
        day: ScheduleDay.fromJson(json.readObject('day')),
        start: switch (json['start']) {
          final Map<String, Object?> start => WorkBoundary.fromJson(start),
          _ => null,
        },
        finish: switch (json['finish']) {
          final Map<String, Object?> finish => WorkBoundary.fromJson(finish),
          _ => null,
        },
      );

  final ScheduleDay day;
  final WorkBoundary? start;
  final WorkBoundary? finish;

  Map<String, Object?> toJson() => {'day': day.toJson(), 'start': start?.toJson(), 'finish': finish?.toJson()};
}

/// The break on one weekday: deducted automatically; only its length counts.
class BreakSchedule {
  const BreakSchedule({required this.day, required this.usualStart, required this.lengthMinutes});

  factory BreakSchedule.fromJson(Map<String, Object?> json) => BreakSchedule(
        day: ScheduleDay.fromJson(json.readObject('day')),
        usualStart: json.readString('usualStart'),
        lengthMinutes: json.readInt('lengthMinutes'),
      );

  final ScheduleDay day;

  /// Wall-clock `HH:mm`.
  final String usualStart;
  final int lengthMinutes;

  Map<String, Object?> toJson() => {'day': day.toJson(), 'usualStart': usualStart, 'lengthMinutes': lengthMinutes};
}

/// Who the rounding of a schedule favours, as HR chose it.
enum ScheduleRoundingFavour {
  /// Starts round up, finishes round down.
  company,

  /// Starts round down, finishes round up.
  employee,

  /// The rules match neither (e.g. changed outside Jitan): HR sees them as they are.
  mixed,
}

/// One set of schedules that some of a group's employees have.
class ScheduleVariant {
  const ScheduleVariant({required this.employeeCount, required this.workDays, required this.breaks, this.favour});

  factory ScheduleVariant.fromJson(Map<String, Object?> json) => ScheduleVariant(
        employeeCount: json.readInt('employeeCount'),
        workDays: json.readObjectList('workDays').map(WorkDaySchedule.fromJson).toList(),
        breaks: json.readObjectList('breaks').map(BreakSchedule.fromJson).toList(),
        favour: switch (json.readOptionalString('favour')) {
          final String name => ScheduleRoundingFavour.values.byName(name),
          null => null,
        },
      );

  final int employeeCount;

  /// Monday first.
  final List<WorkDaySchedule> workDays;
  final List<BreakSchedule> breaks;

  /// `null` when there are no work hours (so no rounding).
  final ScheduleRoundingFavour? favour;

  Map<String, Object?> toJson() => {
        'employeeCount': employeeCount,
        'workDays': [for (final day in workDays) day.toJson()],
        'breaks': [for (final b in breaks) b.toJson()],
        'favour': favour?.name,
      };
}

/// What Jitan found for a group.
enum GroupScheduleStatus {
  /// Every employee who is only in this group has the same schedules.
  configured,

  /// Those employees have no schedules yet.
  noSchedule,

  /// Those employees have different schedules: each set is a variant; none
  /// is picked.
  employeesDiffer,

  /// No employee is only in this group, so it has no schedule of its own.
  noSingleGroupEmployees,
}

/// A group's schedules, taken from the employees who are only in that group
/// (`tblUserGroup` → `tblUserSchedule` → `tblSchedule`; there is no
/// group → schedule link in the ERD).
class GroupSchedule {
  const GroupSchedule({
    required this.group,
    required this.status,
    required this.singleGroupEmployeeCount,
    required this.variants,
  });

  factory GroupSchedule.fromJson(Map<String, Object?> json) => GroupSchedule(
        group: GroupSummary.fromJson(json.readObject('group')),
        status: GroupScheduleStatus.values.byName(json.readString('status')),
        singleGroupEmployeeCount: json.readInt('singleGroupEmployeeCount'),
        variants: json.readObjectList('variants').map(ScheduleVariant.fromJson).toList(),
      );

  final GroupSummary group;
  final GroupScheduleStatus status;
  final int singleGroupEmployeeCount;

  /// One for [GroupScheduleStatus.configured], several for
  /// [GroupScheduleStatus.employeesDiffer] (largest first), none otherwise.
  final List<ScheduleVariant> variants;

  Map<String, Object?> toJson() => {
        'group': group.toJson(),
        'status': status.name,
        'singleGroupEmployeeCount': singleGroupEmployeeCount,
        'variants': [for (final variant in variants) variant.toJson()],
      };
}

/// Response body of `GET /schedules`.
class GroupScheduleListResponse {
  const GroupScheduleListResponse({required this.groups});

  factory GroupScheduleListResponse.fromJson(Map<String, Object?> json) =>
      GroupScheduleListResponse(groups: json.readObjectList('groups').map(GroupSchedule.fromJson).toList());

  final List<GroupSchedule> groups;

  Map<String, Object?> toJson() => {
        'groups': [for (final group in groups) group.toJson()],
      };
}
