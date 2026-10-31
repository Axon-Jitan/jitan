import 'json_reading.dart';
import 'time_record.dart';

/// How the hours chart groups a period.
enum DashboardBucketSize {
  day('day'),
  week('week'),
  month('month');

  const DashboardBucketSize(this.wireName);

  final String wireName;

  static DashboardBucketSize fromWire(String value) => values.firstWhere(
    (s) => s.wireName == value,
    orElse: () => throw FormatException('Unknown bucket size "$value".'),
  );
}

/// One bar of the hours chart.
class DashboardHoursBucket {
  const DashboardHoursBucket({
    required this.from,
    required this.to,
    required this.registeredMinutes,
    required this.plannedMinutes,
  });

  factory DashboardHoursBucket.fromJson(Map<String, Object?> json) => DashboardHoursBucket(
    from: TimeRecordDay.parseDate(json.readString('from')),
    to: TimeRecordDay.parseDate(json.readString('to')),
    registeredMinutes: json.readInt('registeredMinutes'),
    plannedMinutes: json.readInt('plannedMinutes'),
  );

  final DateTime from;
  final DateTime to;
  final int registeredMinutes;
  final int plannedMinutes;

  Map<String, Object?> toJson() => {
    'from': TimeRecordDay.dateText(from),
    'to': TimeRecordDay.dateText(to),
    'registeredMinutes': registeredMinutes,
    'plannedMinutes': plannedMinutes,
  };
}

class DashboardCompany {
  const DashboardCompany({required this.id, required this.name, required this.employees});

  factory DashboardCompany.fromJson(Map<String, Object?> json) =>
      DashboardCompany(id: json.readInt('id'), name: json.readString('name'), employees: json.readInt('employees'));

  final int id;
  final String name;
  final int employees;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'employees': employees};
}

/// Response body of `GET /dashboard?from=&to=`. Calculated when opened from
/// the same days as Time records; only what Jitan can calculate.
class Dashboard {
  const Dashboard({
    required this.working,
    required this.finished,
    required this.notStarted,
    required this.companies,
    required this.employees,
    required this.employeesSetUp,
    required this.locations,
    required this.registeredMinutes,
    required this.plannedMinutes,
    required this.bucketSize,
    required this.buckets,
    required this.onTime,
    required this.late,
    required this.leftEarly,
    required this.toReview,
    required this.correctionsWaiting,
  });

  factory Dashboard.fromJson(Map<String, Object?> json) => Dashboard(
    working: json.readInt('working'),
    finished: json.readInt('finished'),
    notStarted: json.readInt('notStarted'),
    companies: json.readObjectList('companies').map(DashboardCompany.fromJson).toList(),
    employees: json.readInt('employees'),
    employeesSetUp: json.readInt('employeesSetUp'),
    locations: json.readInt('locations'),
    registeredMinutes: json.readInt('registeredMinutes'),
    plannedMinutes: json.readInt('plannedMinutes'),
    bucketSize: DashboardBucketSize.fromWire(json.readString('bucketSize')),
    buckets: json.readObjectList('buckets').map(DashboardHoursBucket.fromJson).toList(),
    onTime: json.readInt('onTime'),
    late: json.readInt('late'),
    leftEarly: json.readInt('leftEarly'),
    toReview: json.readInt('toReview'),
    correctionsWaiting: json.readInt('correctionsWaiting'),
  );

  /// The longest period the Dashboard takes.
  static const maxDays = 366;

  // Today, whatever the period.
  final int working;
  final int finished;
  final int notStarted;

  // Now, whatever the period.
  final List<DashboardCompany> companies;

  /// Each employee once, also when in several companies.
  final int employees;
  final int employeesSetUp;
  final int locations;
  final int correctionsWaiting;

  // The period.
  final int registeredMinutes;
  final int plannedMinutes;
  final DashboardBucketSize bucketSize;
  final List<DashboardHoursBucket> buckets;
  final int onTime;
  final int late;
  final int leftEarly;
  final int toReview;

  int get employeesNotSetUp => employees - employeesSetUp;

  Map<String, Object?> toJson() => {
    'working': working,
    'finished': finished,
    'notStarted': notStarted,
    'companies': [for (final company in companies) company.toJson()],
    'employees': employees,
    'employeesSetUp': employeesSetUp,
    'locations': locations,
    'registeredMinutes': registeredMinutes,
    'plannedMinutes': plannedMinutes,
    'bucketSize': bucketSize.wireName,
    'buckets': [for (final bucket in buckets) bucket.toJson()],
    'onTime': onTime,
    'late': late,
    'leftEarly': leftEarly,
    'toReview': toReview,
    'correctionsWaiting': correctionsWaiting,
  };
}
