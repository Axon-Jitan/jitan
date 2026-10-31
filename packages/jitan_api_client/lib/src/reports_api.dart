import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin reports.
class ReportsApi {
  const ReportsApi(this._transport);

  final ApiTransport _transport;

  /// Each employee's [month] (`yyyy-MM`), of [companyId] or of every company
  /// the viewer may see.
  Future<HoursReport> hours(String month, {int? companyId}) async {
    final json = await _transport.getJson(
      'reports/hours',
      query: {'month': month, 'company': ?companyId?.toString()},
    );
    try {
      return HoursReport.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Hours report: ${e.message}');
    }
  }
}
