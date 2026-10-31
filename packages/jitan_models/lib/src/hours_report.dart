import 'json_reading.dart';
import 'time_record.dart';

/// One day of an employee's month in the hours report.
class HoursReportDay {
  const HoursReportDay({
    required this.date,
    required this.status,
    this.start,
    this.finish,
    this.registeredMinutes,
    this.awayMinutes = 0,
  });

  factory HoursReportDay.fromJson(Map<String, Object?> json) => HoursReportDay(
    date: TimeRecordDay.parseDate(json.readString('date')),
    status: TimeRecordStatus.fromWire(json.readString('status')),
    start: json.readOptionalString('start'),
    finish: json.readOptionalString('finish'),
    registeredMinutes: json.readOptionalInt('registeredMinutes'),
    awayMinutes: json.readOptionalInt('awayMinutes') ?? 0,
  );

  final DateTime date;
  final TimeRecordStatus status;

  /// Workplace-local rounded times, `HH:mm`.
  final String? start;
  final String? finish;

  /// `null` until the day is finished and nothing waits for HR.
  final int? registeredMinutes;
  final int awayMinutes;

  Map<String, Object?> toJson() => {
    'date': TimeRecordDay.dateText(date),
    'status': status.wireName,
    'start': start,
    'finish': finish,
    'registeredMinutes': registeredMinutes,
    'awayMinutes': awayMinutes,
  };
}

/// One employee's month: what was planned, what was registered, and how many
/// days still need someone to look at them.
class HoursReportEmployee {
  const HoursReportEmployee({
    required this.employeeId,
    required this.code,
    required this.plannedMinutes,
    required this.registeredMinutes,
    required this.daysToReview,
    required this.days,
    this.firstName,
    this.lastName,
  });

  factory HoursReportEmployee.fromJson(Map<String, Object?> json) => HoursReportEmployee(
    employeeId: json.readInt('employeeId'),
    firstName: json.readOptionalString('firstName'),
    lastName: json.readOptionalString('lastName'),
    code: json.readString('code'),
    plannedMinutes: json.readInt('plannedMinutes'),
    registeredMinutes: json.readInt('registeredMinutes'),
    daysToReview: json.readInt('daysToReview'),
    days: json.readObjectList('days').map(HoursReportDay.fromJson).toList(),
  );

  final int employeeId;
  final String? firstName;
  final String? lastName;
  final String code;

  /// The schedule's work time up to today, without non-work days.
  final int plannedMinutes;

  /// Only finished days with nothing waiting for HR.
  final int registeredMinutes;
  final int daysToReview;

  /// The days with something to show, newest first.
  final List<HoursReportDay> days;

  int get differenceMinutes => registeredMinutes - plannedMinutes;

  Map<String, Object?> toJson() => {
    'employeeId': employeeId,
    'firstName': firstName,
    'lastName': lastName,
    'code': code,
    'plannedMinutes': plannedMinutes,
    'registeredMinutes': registeredMinutes,
    'daysToReview': daysToReview,
    'days': [for (final day in days) day.toJson()],
  };
}

/// Response body of `GET /reports/hours`.
class HoursReport {
  const HoursReport({required this.month, required this.employees});

  factory HoursReport.fromJson(Map<String, Object?> json) => HoursReport(
    month: json.readString('month'),
    employees: json.readObjectList('employees').map(HoursReportEmployee.fromJson).toList(),
  );

  /// `yyyy-MM`.
  final String month;
  final List<HoursReportEmployee> employees;

  Map<String, Object?> toJson() => {
    'month': month,
    'employees': [for (final employee in employees) employee.toJson()],
  };
}
