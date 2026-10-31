import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  final dashboard = Dashboard(
    working: 3,
    finished: 2,
    notStarted: 1,
    companies: const [DashboardCompany(id: 7, name: 'Almeco', employees: 48)],
    employees: 124,
    employeesSetUp: 109,
    locations: 3,
    registeredMinutes: 480,
    plannedMinutes: 960,
    bucketSize: DashboardBucketSize.week,
    buckets: [
      DashboardHoursBucket(
        from: DateTime.utc(2026, 10, 19),
        to: DateTime.utc(2026, 10, 25),
        registeredMinutes: 480,
        plannedMinutes: 960,
      ),
    ],
    onTime: 268,
    late: 16,
    leftEarly: 6,
    toReview: 4,
    correctionsWaiting: 2,
  );

  test('comes back the same from JSON', () {
    final back = Dashboard.fromJson(dashboard.toJson());

    expect(back.toJson(), dashboard.toJson());
    expect(back.bucketSize, DashboardBucketSize.week);
    expect(back.buckets.single.from, DateTime.utc(2026, 10, 19));
  });

  test('employees not set up are the difference', () {
    expect(dashboard.employeesNotSetUp, 15);
  });

  test('an unknown bar size is a format error', () {
    expect(() => Dashboard.fromJson({...dashboard.toJson(), 'bucketSize': 'hour'}), throwsFormatException);
  });
}
