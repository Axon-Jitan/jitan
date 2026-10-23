import 'json_reading.dart';
import 'time_record.dart';

/// One day of `GET /me/period`: the day as on HR's Time records (`null`
/// without registrations), the time planned by the schedule and the time
/// registered once the day is finished.
class MyPeriodDay {
  const MyPeriodDay({
    required this.date,
    this.day,
    this.scheduledStart,
    this.scheduledFinish,
    this.plannedMinutes,
    this.registeredMinutes,
  });

  factory MyPeriodDay.fromJson(Map<String, Object?> json) => MyPeriodDay(
        date: TimeRecordDay.parseDate(json.readString('date')),
        day: json['day'] == null ? null : TimeRecordDay.fromJson(json.readObject('day')),
        scheduledStart: json.readOptionalString('scheduledStart'),
        scheduledFinish: json.readOptionalString('scheduledFinish'),
        plannedMinutes: json.readOptionalInt('plannedMinutes'),
        registeredMinutes: json.readOptionalInt('registeredMinutes'),
      );

  /// The workplace-local calendar day.
  final DateTime date;
  final TimeRecordDay? day;

  /// The schedule of that weekday, `HH:mm`; `null` on a day off.
  final String? scheduledStart;
  final String? scheduledFinish;

  /// Work window minus break; `null` on a day off.
  final int? plannedMinutes;

  /// Rounded finish − rounded start − break (D4, D13); `null` while the day
  /// is open, has no registration, or a correction waits for HR (D31).
  final int? registeredMinutes;

  /// A day the employee should look at: a missing start or finish, a day
  /// without registration, or a correction waiting for HR.
  bool get needsAttention => switch (day?.status) {
        TimeRecordStatus.missingStart ||
        TimeRecordStatus.missingFinish ||
        TimeRecordStatus.noRegistration ||
        TimeRecordStatus.pendingReview =>
          true,
        _ => false,
      };

  Map<String, Object?> toJson() => {
        'date': TimeRecordDay.dateText(date),
        'day': day?.toJson(),
        'scheduledStart': scheduledStart,
        'scheduledFinish': scheduledFinish,
        'plannedMinutes': plannedMinutes,
        'registeredMinutes': registeredMinutes,
      };
}

/// Response of `GET /me/period?from=&to=`: the signed-in employee's days
/// for Period (Figma `35:57` this day, `48:2` week, `48:49` month, `99:56`
/// day details).
class MyPeriod {
  const MyPeriod({required this.from, required this.to, required this.days});

  factory MyPeriod.fromJson(Map<String, Object?> json) => MyPeriod(
        from: TimeRecordDay.parseDate(json.readString('from')),
        to: TimeRecordDay.parseDate(json.readString('to')),
        days: json.readObjectList('days').map(MyPeriodDay.fromJson).toList(),
      );

  /// The longest period asked at once: a month and a bit.
  static const maxDays = 62;

  final DateTime from;
  final DateTime to;

  /// Every day from [from] to [to], in order.
  final List<MyPeriodDay> days;

  int get plannedMinutes => days.fold(0, (sum, d) => sum + (d.plannedMinutes ?? 0));
  int get registeredMinutes => days.fold(0, (sum, d) => sum + (d.registeredMinutes ?? 0));

  Map<String, Object?> toJson() => {
        'from': TimeRecordDay.dateText(from),
        'to': TimeRecordDay.dateText(to),
        'days': [for (final d in days) d.toJson()],
      };
}
