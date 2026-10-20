import 'group_summary.dart';
import 'json_reading.dart';
import 'schedule.dart';

/// Work hours on one day of a [SetWorkHoursRequest].
class WorkHoursDay {
  const WorkHoursDay({required this.dayId, required this.start, required this.finish});

  factory WorkHoursDay.fromJson(Map<String, Object?> json) =>
      WorkHoursDay(dayId: json.readInt('dayId'), start: json.readString('start'), finish: json.readString('finish'));

  /// `tblDays.dayID`.
  final int dayId;

  /// Wall-clock `HH:mm`; [finish] is after [start] on the same day.
  final String start;
  final String finish;

  Map<String, Object?> toJson() => {'dayId': dayId, 'start': start, 'finish': finish};
}

/// Body of `PUT /schedules/groups/{groupId}/work-hours`: the group's work
/// hours, replacing any it had. Applies from now; registrations already made
/// keep their times.
class SetWorkHoursRequest {
  const SetWorkHoursRequest({
    required this.days,
    required this.arrivalToleranceMinutes,
    required this.leavingToleranceMinutes,
    this.startRounding,
    this.finishRounding,
  });

  factory SetWorkHoursRequest.fromJson(Map<String, Object?> json) => SetWorkHoursRequest(
        days: json.readObjectList(fieldDays).map(WorkHoursDay.fromJson).toList(),
        arrivalToleranceMinutes: json.readInt(fieldArrivalTolerance),
        leavingToleranceMinutes: json.readInt(fieldLeavingTolerance),
        startRounding: _rounding(json[fieldStartRounding], fieldStartRounding),
        finishRounding: _rounding(json[fieldFinishRounding], fieldFinishRounding),
      );

  final List<WorkHoursDay> days;

  /// Minutes after the start an arrival still counts as on time.
  final int arrivalToleranceMinutes;

  /// Minutes before the finish a departure is within tolerance.
  final int leavingToleranceMinutes;

  /// `null`: the start is not rounded.
  final ScheduleRounding? startRounding;

  /// `null`: the finish is not rounded.
  final ScheduleRounding? finishRounding;

  /// Field names, for [ApiError.field].
  static const fieldDays = 'days';
  static const fieldArrivalTolerance = 'arrivalToleranceMinutes';
  static const fieldLeavingTolerance = 'leavingToleranceMinutes';
  static const fieldStartRounding = 'startRounding';
  static const fieldFinishRounding = 'finishRounding';

  Map<String, Object?> toJson() => {
        fieldDays: [for (final day in days) day.toJson()],
        fieldArrivalTolerance: arrivalToleranceMinutes,
        fieldLeavingTolerance: leavingToleranceMinutes,
        fieldStartRounding: startRounding?.toJson(),
        fieldFinishRounding: finishRounding?.toJson(),
      };

  static ScheduleRounding? _rounding(Object? value, String field) => switch (value) {
        null => null,
        final Map<String, Object?> rounding => ScheduleRounding.fromJson(rounding),
        _ => throw FormatException('"$field" must be an object or null.'),
      };
}

/// The break on one day of a [SetBreaksRequest].
class BreakDay {
  const BreakDay({required this.dayId, required this.usualStart, required this.lengthMinutes});

  factory BreakDay.fromJson(Map<String, Object?> json) => BreakDay(
        dayId: json.readInt('dayId'),
        usualStart: json.readString('usualStart'),
        lengthMinutes: json.readInt('lengthMinutes'),
      );

  final int dayId;

  /// Wall-clock `HH:mm`.
  final String usualStart;
  final int lengthMinutes;

  Map<String, Object?> toJson() => {'dayId': dayId, 'usualStart': usualStart, 'lengthMinutes': lengthMinutes};
}

/// Body of `PUT /schedules/groups/{groupId}/breaks`: the group's breaks,
/// replacing any it had. Each break lies within the group's work hours of
/// that day and is deducted automatically.
class SetBreaksRequest {
  const SetBreaksRequest({required this.days});

  factory SetBreaksRequest.fromJson(Map<String, Object?> json) =>
      SetBreaksRequest(days: json.readObjectList(fieldDays).map(BreakDay.fromJson).toList());

  final List<BreakDay> days;

  static const fieldDays = 'days';

  Map<String, Object?> toJson() => {
        fieldDays: [for (final day in days) day.toJson()],
      };
}

/// Response body of `GET …/employees/{userId}/assignments/schedule-source`:
/// the employee's groups and the one their schedule comes from.
class ScheduleSourceResponse {
  const ScheduleSourceResponse({required this.groups, this.sourceGroupId});

  factory ScheduleSourceResponse.fromJson(Map<String, Object?> json) => ScheduleSourceResponse(
        groups: json.readObjectList('groups').map(GroupSummary.fromJson).toList(),
        sourceGroupId: json.readOptionalInt('sourceGroupId'),
      );

  /// The employee's current, active groups.
  final List<GroupSummary> groups;

  /// `null` when the employee has no schedule, or it isn't exactly one
  /// group's (HR then chooses).
  final int? sourceGroupId;

  Map<String, Object?> toJson() => {
        'groups': [for (final group in groups) group.toJson()],
        'sourceGroupId': sourceGroupId,
      };
}

/// Body of `PUT …/employees/{userId}/assignments/schedule-source`: "Schedules
/// come from" one of the employee's groups.
class ScheduleSourceRequest {
  const ScheduleSourceRequest({required this.groupId});

  factory ScheduleSourceRequest.fromJson(Map<String, Object?> json) =>
      ScheduleSourceRequest(groupId: json.readInt(fieldGroupId));

  final int groupId;

  static const fieldGroupId = 'groupId';

  Map<String, Object?> toJson() => {fieldGroupId: groupId};
}
