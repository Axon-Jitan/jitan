import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// HR/Admin Dashboard.
class DashboardApi {
  const DashboardApi(this._transport);

  final ApiTransport _transport;

  /// Today and the totals, with the period from [from] to [to] (local dates).
  Future<Dashboard> dashboard(DateTime from, DateTime to) async {
    final json = await _transport.getJson(
      'dashboard',
      query: {'from': TimeRecordDay.dateText(from), 'to': TimeRecordDay.dateText(to)},
    );
    try {
      return Dashboard.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Dashboard: ${e.message}');
    }
  }
}
