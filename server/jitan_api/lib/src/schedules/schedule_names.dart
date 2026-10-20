/// Names of the `tblScheduleType` rows Jitan relies on, exactly as in
/// docs/database/reference_data.sql. Rows are found by name, never by ID
/// (the same pattern as `AuditEventType`). Changing a name means changing
/// reference_data.sql in the same commit.
abstract final class ScheduleTypeNames {
  /// The start of a working day: its time, tolerance and rounding rule.
  static const workStart = 'Work – start';

  /// The finish of a working day.
  static const workFinish = 'Work – finish';

  /// A break, deducted automatically; only its length counts.
  static const breakTime = 'Break';

  static const all = [workStart, workFinish, breakTime];
}

/// The `tblDays.dayName` of each ISO weekday (1 = Monday … 7 = Sunday), as
/// in docs/database/reference_data.sql. Jitan must know which row is Monday
/// to apply the right schedule on a date.
abstract final class DayNames {
  static const _weekdays = {
    'Monday': DateTime.monday,
    'Tuesday': DateTime.tuesday,
    'Wednesday': DateTime.wednesday,
    'Thursday': DateTime.thursday,
    'Friday': DateTime.friday,
    'Saturday': DateTime.saturday,
    'Sunday': DateTime.sunday,
  };

  /// The weekday of [dayName], or `null` for a name Jitan doesn't know.
  static int? weekdayOf(String dayName) => _weekdays[dayName];
}
