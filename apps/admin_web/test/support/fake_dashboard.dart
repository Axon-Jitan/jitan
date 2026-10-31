import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// A Dashboard with something in every card.
Dashboard dashboardWith({
  int working = 98,
  int finished = 8,
  int notStarted = 14,
  int employees = 124,
  int employeesSetUp = 109,
  int toReview = 4,
  int corrections = 2,
  int registered = 187620,
  int planned = 192000,
  List<DashboardCompany> companies = const [
    DashboardCompany(id: 1, name: 'Almeco', employees: 48),
    DashboardCompany(id: 2, name: 'PCA', employees: 36),
    DashboardCompany(id: 3, name: 'Akwa Plus', employees: 21),
    DashboardCompany(id: 4, name: 'Proceq', employees: 19),
  ],
  DashboardBucketSize bucketSize = DashboardBucketSize.day,
  int bars = 7,
}) => Dashboard(
  working: working,
  finished: finished,
  notStarted: notStarted,
  companies: companies,
  employees: employees,
  employeesSetUp: employeesSetUp,
  locations: 3,
  registeredMinutes: registered,
  plannedMinutes: planned,
  bucketSize: bucketSize,
  buckets: [
    for (var i = 0; i < bars; i++)
      DashboardHoursBucket(
        from: DateTime.utc(2026, 10, 1 + i % 28),
        to: DateTime.utc(2026, 10, 1 + i % 28),
        registeredMinutes: 36000 + i * 600,
        plannedMinutes: 38400,
      ),
  ],
  onTime: 268,
  late: 16,
  leftEarly: 6,
  toReview: toReview,
  correctionsWaiting: corrections,
);

/// Stand-in for [DashboardApi].
class FakeDashboardApi implements DashboardApi {
  Dashboard answer = dashboardWith();
  ApiClientException? fail;
  final calls = <(DateTime, DateTime)>[];

  @override
  Future<Dashboard> dashboard(DateTime from, DateTime to) async {
    calls.add((from, to));
    if (fail case final failure?) throw failure;
    return answer;
  }
}
