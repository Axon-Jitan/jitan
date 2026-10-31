import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

HoursReportEmployee reportEmployee(
  int id,
  String first,
  String last,
  String code, {
  int planned = 9600,
  int registered = 9600,
  int toReview = 0,
  List<HoursReportDay> days = const [],
}) => HoursReportEmployee(
  employeeId: id,
  firstName: first,
  lastName: last,
  code: code,
  plannedMinutes: planned,
  registeredMinutes: registered,
  daysToReview: toReview,
  days: days,
);

/// Stand-in for [ReportsApi]: the same employees for every month, except
/// [emptyMonths].
class FakeReportsApi implements ReportsApi {
  List<HoursReportEmployee> employees = [];
  Set<String> emptyMonths = {};
  ApiClientException? fail;
  final calls = <(String, int?)>[];

  @override
  Future<HoursReport> hours(String month, {int? companyId}) async {
    calls.add((month, companyId));
    if (fail case final failure?) throw failure;
    return HoursReport(month: month, employees: emptyMonths.contains(month) ? const [] : employees);
  }
}
