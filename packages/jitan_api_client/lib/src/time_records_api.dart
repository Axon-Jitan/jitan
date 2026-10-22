import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `GET /time-records`: HR/Admin Time records.
class TimeRecordsApi {
  const TimeRecordsApi(this._transport);

  final ApiTransport _transport;

  /// The working days from [from] to [to] (workplace-local calendar days,
  /// both inclusive) of [companyId]'s employees, or of every company when
  /// `null`; [search] matches name or code.
  Future<List<TimeRecordDay>> list({required DateTime from, required DateTime to, int? companyId, String? search}) async {
    final term = search?.trim() ?? '';
    final json = await _transport.getJson(
      'time-records',
      query: {
        'from': TimeRecordDay.dateText(from),
        'to': TimeRecordDay.dateText(to),
        'company': ?companyId?.toString(),
        if (term.isNotEmpty) 'search': term,
      },
    );
    try {
      return TimeRecordList.fromJson(json).days;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Time records: ${e.message}');
    }
  }
}
