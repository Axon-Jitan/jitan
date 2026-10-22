import 'json_reading.dart';

/// The status of an employee's day in Time records (TIME_ENGINE_ANALYSIS
/// D14: calculated from the registrations, never stored).
enum TimeRecordStatus {
  complete('complete'),

  /// Started today and not finished yet: no problem, still at work.
  working('working'),

  /// Started on an earlier day and never finished.
  missingFinish('missing_finish'),

  /// Finished without a start.
  missingStart('missing_start');

  const TimeRecordStatus(this.wireName);

  final String wireName;

  static TimeRecordStatus fromWire(String value) => values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => throw FormatException('Unknown time record status "$value".'),
      );
}

/// How a time was registered: the method of its "actual" `tblTimeRegType`
/// ("Start – actual – Geofence" …), shown as Automatic / QR / Employee.
enum TimeRecordMethod {
  geofence('geofence'),
  qr('qr'),
  manual('manual');

  const TimeRecordMethod(this.wireName);

  final String wireName;

  static TimeRecordMethod fromWire(String value) => values.firstWhere(
        (m) => m.wireName == value,
        orElse: () => throw FormatException('Unknown method "$value".'),
      );
}

/// A day's start or finish: the actual time (as registered, never changed)
/// and the rounded time stored with it (D4), both UTC.
class TimeRecordTime {
  const TimeRecordTime({
    required this.actualId,
    required this.actual,
    required this.rounded,
    required this.method,
    required this.enteredByHand,
    required this.actualLocal,
    this.roundedLocal,
    this.reason,
  });

  factory TimeRecordTime.fromJson(Map<String, Object?> json) => TimeRecordTime(
        actualId: json.readInt('actualId'),
        actual: DateTime.parse(json.readString('actual')).toUtc(),
        rounded: json['rounded'] == null ? null : DateTime.parse(json.readString('rounded')).toUtc(),
        method: TimeRecordMethod.fromWire(json.readString('method')),
        enteredByHand: json.readBool('enteredByHand'),
        actualLocal: json.readString('actualLocal'),
        roundedLocal: json.readOptionalString('roundedLocal'),
        reason: json.readOptionalString('reason'),
      );

  /// `tblTimeReg.timeRegID` of the actual row.
  final int actualId;
  final DateTime actual;

  /// `null` when no rounded row was stored with it.
  final DateTime? rounded;
  final TimeRecordMethod method;

  /// `timeRegManualEntry`: the time was entered afterwards (a correction or
  /// the first day, D30), not tapped or detected when it happened.
  final bool enteredByHand;

  /// `timeRegComment`: why it was corrected.
  final String? reason;

  /// [actual] and [rounded] in the workplace's local time, `HH:mm`, as the
  /// server converts them (clients never convert times themselves).
  final String actualLocal;
  final String? roundedLocal;

  Map<String, Object?> toJson() => {
        'actualId': actualId,
        'actual': actual.toUtc().toIso8601String(),
        'rounded': rounded?.toUtc().toIso8601String(),
        'method': method.wireName,
        'enteredByHand': enteredByHand,
        'actualLocal': actualLocal,
        'roundedLocal': roundedLocal,
        'reason': reason,
      };
}

/// One employee's working day in Time records (Figma `160:2`, `160:94`):
/// the first start and the last finish of the workplace-local [date].
class TimeRecordDay {
  const TimeRecordDay({
    required this.employeeId,
    required this.employeeCode,
    required this.date,
    required this.status,
    this.firstName,
    this.lastName,
    this.start,
    this.finish,
  });

  factory TimeRecordDay.fromJson(Map<String, Object?> json) => TimeRecordDay(
        employeeId: json.readInt('employeeId'),
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        employeeCode: json.readString('employeeCode'),
        date: _calendarDate(json.readString('date')),
        status: TimeRecordStatus.fromWire(json.readString('status')),
        start: json['start'] == null ? null : TimeRecordTime.fromJson(json.readObject('start')),
        finish: json['finish'] == null ? null : TimeRecordTime.fromJson(json.readObject('finish')),
      );

  final int employeeId;
  final String? firstName;
  final String? lastName;
  final String employeeCode;

  /// The workplace-local calendar day, as a UTC-flagged date at midnight
  /// (no time zone meant).
  final DateTime date;
  final TimeRecordStatus status;
  final TimeRecordTime? start;
  final TimeRecordTime? finish;

  Map<String, Object?> toJson() => {
        'employeeId': employeeId,
        'firstName': firstName,
        'lastName': lastName,
        'employeeCode': employeeCode,
        'date': dateText(date),
        'status': status.wireName,
        'start': start?.toJson(),
        'finish': finish?.toJson(),
      };

  /// A `yyyy-MM-dd` date as a UTC-flagged calendar day (no time zone meant).
  static DateTime _calendarDate(String text) {
    final d = DateTime.parse(text);
    return DateTime.utc(d.year, d.month, d.day);
  }

  /// `yyyy-MM-dd`.
  static String dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Response of `GET /time-records`: the days, newest first, then by name.
class TimeRecordList {
  const TimeRecordList({required this.days});

  factory TimeRecordList.fromJson(Map<String, Object?> json) =>
      TimeRecordList(days: json.readObjectList('days').map(TimeRecordDay.fromJson).toList());

  final List<TimeRecordDay> days;

  /// Longest period one request may cover, in days.
  static const maxPeriodDays = 62;

  Map<String, Object?> toJson() => {'days': [for (final d in days) d.toJson()]};
}
