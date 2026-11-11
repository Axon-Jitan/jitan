import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin reports.
class ReportsApi {
  const ReportsApi(this._transport);

  final ApiTransport _transport;

  /// Each employee's period [from]–[to] (both included), of [companyId] or of
  /// every company the viewer may see.
  Future<HoursReport> hours(DateTime from, DateTime to, {int? companyId}) async {
    final json = await _transport.getJson(
      'reports/hours',
      query: {'from': TimeRecordDay.dateText(from), 'to': TimeRecordDay.dateText(to), 'company': ?companyId?.toString()},
    );
    try {
      return HoursReport.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Hours report: ${e.message}');
    }
  }

  /// Each project's period [from]–[to] (both included), with the employees of
  /// every company the viewer may see (D24).
  Future<ProjectReport> projects(DateTime from, DateTime to) async {
    final json = await _transport.getJson(
      'reports/projects',
      query: {'from': TimeRecordDay.dateText(from), 'to': TimeRecordDay.dateText(to)},
    );
    try {
      return ProjectReport.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Project report: ${e.message}');
    }
  }
}
