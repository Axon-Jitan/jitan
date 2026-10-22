import 'json_reading.dart';
import 'time_registration_write.dart';

/// The status of an employee's day in Time records (TIME_ENGINE_ANALYSIS
/// D14, D31: calculated from the registrations, never stored).
enum TimeRecordStatus {
  complete('complete'),

  /// Complete, with a time corrected by HR (or an approved employee
  /// correction).
  corrected('corrected'),

  /// The employee corrected a time; it does not count until HR approves it.
  pendingReview('pending_review'),

  /// Started today and not finished yet: no problem, still at work.
  working('working'),

  /// Started on an earlier day and never finished.
  missingFinish('missing_finish'),

  /// Finished without a start.
  missingStart('missing_start'),

  /// HR marked the day as non-work: its registrations are switched off.
  nonWork('non_work'),

  /// A past scheduled working day without any registration (GAP-16: why
  /// can not be recorded yet).
  noRegistration('no_registration');

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

/// Who corrected a time.
enum TimeCorrectionBy {
  /// HR's correction, or the employee's correction once HR approved it.
  hr('hr');

  const TimeCorrectionBy(this.wireName);

  final String wireName;

  static TimeCorrectionBy? fromWire(String? value) => value == null
      ? null
      : values.firstWhere((b) => b.wireName == value, orElse: () => throw FormatException('Unknown corrector "$value".'));
}

/// A day's start or finish as it counts: the time (the registration, or HR's
/// corrected time) and the rounded time stored with it (D4, D7), both UTC.
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
    this.correctedBy,
    this.originalLocal,
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
        correctedBy: TimeCorrectionBy.fromWire(json.readOptionalString('correctedBy')),
        originalLocal: json.readOptionalString('originalLocal'),
      );

  /// `tblTimeReg.timeRegID` of the row that counts (actual or corrected).
  final int actualId;
  final DateTime actual;

  /// `null` when no rounded row was stored with it.
  final DateTime? rounded;

  /// How it was first registered; [TimeRecordMethod.manual] for a time HR
  /// added where nothing was registered.
  final TimeRecordMethod method;

  /// `timeRegManualEntry`: entered afterwards (a correction or the first
  /// day, D30), not tapped or detected when it happened.
  final bool enteredByHand;

  /// `timeRegComment`: why it was corrected.
  final String? reason;

  /// Set when the time is a correction.
  final TimeCorrectionBy? correctedBy;

  /// [actual] and [rounded] in the workplace's local time, `HH:mm`, as the
  /// server converts them (clients never convert times themselves).
  final String actualLocal;
  final String? roundedLocal;

  /// For a corrected time: the registration it replaced (`HH:mm`), if any.
  final String? originalLocal;

  Map<String, Object?> toJson() => {
        'actualId': actualId,
        'actual': actual.toUtc().toIso8601String(),
        'rounded': rounded?.toUtc().toIso8601String(),
        'method': method.wireName,
        'enteredByHand': enteredByHand,
        'actualLocal': actualLocal,
        'roundedLocal': roundedLocal,
        'reason': reason,
        'correctedBy': correctedBy?.wireName,
        'originalLocal': originalLocal,
      };
}

/// An employee's correction waiting for HR (D31, Figma `160:338`).
class TimeRecordPending {
  const TimeRecordPending({
    required this.id,
    required this.boundary,
    required this.requested,
    required this.requestedLocal,
    required this.reason,
    this.roundedLocal,
  });

  factory TimeRecordPending.fromJson(Map<String, Object?> json) => TimeRecordPending(
        id: json.readInt('id'),
        boundary: RegistrationBoundary.fromWire(json.readString('boundary')),
        requested: DateTime.parse(json.readString('requested')).toUtc(),
        requestedLocal: json.readString('requestedLocal'),
        reason: json.readOptionalString('reason'),
        roundedLocal: json.readOptionalString('roundedLocal'),
      );

  /// `tblTimeReg.timeRegID` of the employee's row.
  final int id;
  final RegistrationBoundary boundary;
  final DateTime requested;
  final String requestedLocal;
  final String? reason;

  /// What it would count as after rounding with the employee's schedule.
  final String? roundedLocal;

  Map<String, Object?> toJson() => {
        'id': id,
        'boundary': boundary.wireName,
        'requested': requested.toUtc().toIso8601String(),
        'requestedLocal': requestedLocal,
        'reason': reason,
        'roundedLocal': roundedLocal,
      };
}

/// What happened in a day's timeline.
enum TimeRecordEventKind {
  /// Detected, scanned or tapped when it happened (or the first day).
  registered('registered'),

  /// The employee corrected a time (pending, approved or rejected).
  correctionRequested('correction_requested'),

  /// HR corrected a time or approved the employee's correction.
  corrected('corrected'),

  /// HR rejected the employee's correction.
  rejected('rejected'),

  /// Switched off when HR marked the day as non-work.
  nonWork('non_work');

  const TimeRecordEventKind(this.wireName);

  final String wireName;

  static TimeRecordEventKind fromWire(String value) => values.firstWhere(
        (k) => k.wireName == value,
        orElse: () => throw FormatException('Unknown event "$value".'),
      );
}

/// One row of a day's detailed timeline: every start and finish stored that
/// day, kept or switched off (nothing is ever deleted).
class TimeRecordEvent {
  const TimeRecordEvent({
    required this.atLocal,
    required this.boundary,
    required this.kind,
    required this.active,
    this.method,
    this.reason,
  });

  factory TimeRecordEvent.fromJson(Map<String, Object?> json) => TimeRecordEvent(
        atLocal: json.readString('atLocal'),
        boundary: RegistrationBoundary.fromWire(json.readString('boundary')),
        kind: TimeRecordEventKind.fromWire(json.readString('kind')),
        active: json.readBool('active'),
        method: json['method'] == null ? null : TimeRecordMethod.fromWire(json.readString('method')),
        reason: json.readOptionalString('reason'),
      );

  final String atLocal;
  final RegistrationBoundary boundary;
  final TimeRecordEventKind kind;

  /// `false` for a row switched off (rejected, replaced or non-work).
  final bool active;
  final TimeRecordMethod? method;
  final String? reason;

  Map<String, Object?> toJson() => {
        'atLocal': atLocal,
        'boundary': boundary.wireName,
        'kind': kind.wireName,
        'active': active,
        'method': method?.wireName,
        'reason': reason,
      };
}

/// One employee's working day in Time records (Figma `160:2`, `160:94`):
/// the first start and the last finish of the workplace-local [date] as they
/// count, the corrections waiting for HR, and the full timeline.
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
    this.pending = const [],
    this.events = const [],
    this.nonWorkReason,
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
        pending: json['pending'] == null ? const [] : json.readObjectList('pending').map(TimeRecordPending.fromJson).toList(),
        events: json['events'] == null ? const [] : json.readObjectList('events').map(TimeRecordEvent.fromJson).toList(),
        nonWorkReason: json.readOptionalString('nonWorkReason'),
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
  final List<TimeRecordPending> pending;
  final List<TimeRecordEvent> events;

  /// Why HR marked the day as non-work.
  final String? nonWorkReason;

  Map<String, Object?> toJson() => {
        'employeeId': employeeId,
        'firstName': firstName,
        'lastName': lastName,
        'employeeCode': employeeCode,
        'date': dateText(date),
        'status': status.wireName,
        'start': start?.toJson(),
        'finish': finish?.toJson(),
        if (pending.isNotEmpty) 'pending': [for (final p in pending) p.toJson()],
        if (events.isNotEmpty) 'events': [for (final e in events) e.toJson()],
        'nonWorkReason': nonWorkReason,
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

/// Body of `POST /companies/{c}/employees/{u}/time-records/{date}/correct`:
/// HR's corrected start or finish of that day (D7: rounded like any time).
/// [time] is the workplace's local time of that day, `HH:mm`; the server
/// converts it (clients never convert times themselves).
class CorrectTimeRequest {
  const CorrectTimeRequest({required this.boundary, required this.time, required this.reason});

  factory CorrectTimeRequest.fromJson(Map<String, Object?> json) => CorrectTimeRequest(
        boundary: RegistrationBoundary.fromWire(json.readString(fieldBoundary)),
        time: localTime(json.readString(fieldTime)),
        reason: json.readString(fieldReason),
      );

  final RegistrationBoundary boundary;
  final String time;
  final String reason;

  static const fieldBoundary = 'boundary';
  static const fieldTime = 'time';
  static const fieldReason = 'reason';

  /// [text] when it is a valid `HH:mm` (00:00–23:59); [FormatException]
  /// otherwise.
  static String localTime(String text) {
    final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(text.trim());
    if (match == null) throw FormatException('"$text" is not a time like 08:30.');
    return text.trim();
  }

  Map<String, Object?> toJson() => {
        fieldBoundary: boundary.wireName,
        fieldTime: time,
        fieldReason: reason,
      };
}

/// Body of `…/time-records/{date}/non-work` (Figma `273:166`).
class MarkNonWorkRequest {
  const MarkNonWorkRequest({required this.reason});

  factory MarkNonWorkRequest.fromJson(Map<String, Object?> json) =>
      MarkNonWorkRequest(reason: json.readString(fieldReason));

  final String reason;

  static const fieldReason = 'reason';

  Map<String, Object?> toJson() => {fieldReason: reason};
}
