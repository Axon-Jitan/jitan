import 'json_reading.dart';
import 'time_record.dart';

/// Response of `GET /me/today`: the signed-in employee's working day as the
/// server sees it (Employee App "Today", Figma 1444:3, 1436:128, 1436:213,
/// 22:2). The app shows it; it never calculates registered time itself
/// (rule §6).
class MyDay {
  const MyDay({
    required this.date,
    required this.firstDay,
    this.scheduledStart,
    this.scheduledFinish,
    this.breakMinutes,
    this.day,
    this.registeredMinutes,
  });

  factory MyDay.fromJson(Map<String, Object?> json) => MyDay(
        date: TimeRecordDay.parseDate(json.readString('date')),
        firstDay: json.readBool('firstDay'),
        scheduledStart: json.readOptionalString('scheduledStart'),
        scheduledFinish: json.readOptionalString('scheduledFinish'),
        breakMinutes: json.readOptionalInt('breakMinutes'),
        day: json['day'] == null ? null : TimeRecordDay.fromJson(json.readObject('day')),
        registeredMinutes: json.readOptionalInt('registeredMinutes'),
      );

  /// Today at the workplace.
  final DateTime date;

  /// The employee has never registered: "When did you arrive?" right after
  /// onboarding (D30, entry `first_day`).
  final bool firstDay;

  /// Today's schedule, workplace-local `HH:mm`; `null` without a schedule
  /// today.
  final String? scheduledStart;
  final String? scheduledFinish;

  /// Today's break length (D13: deducted, never registered).
  final int? breakMinutes;

  /// Today's registrations, as on HR's Time records; `null` when there are
  /// none.
  final TimeRecordDay? day;

  /// Registered time of a finished day: rounded finish − rounded start −
  /// break (D4, D13). `null` while the day is open or a correction waits
  /// for HR (D31).
  final int? registeredMinutes;

  Map<String, Object?> toJson() => {
        'date': TimeRecordDay.dateText(date),
        'firstDay': firstDay,
        'scheduledStart': scheduledStart,
        'scheduledFinish': scheduledFinish,
        'breakMinutes': breakMinutes,
        'day': day?.toJson(),
        'registeredMinutes': registeredMinutes,
      };
}
