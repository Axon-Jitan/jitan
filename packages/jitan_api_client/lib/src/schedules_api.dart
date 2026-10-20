import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/schedules`: the employee groups' schedules and the schedule form's
/// choices (HR/Admin). Schedules are global, not company-scoped.
class SchedulesApi {
  const SchedulesApi(this._transport);

  final ApiTransport _transport;

  /// Every active group with its schedules.
  Future<List<GroupSchedule>> groupSchedules() async {
    final json = await _transport.getJson('schedules');
    try {
      return GroupScheduleListResponse.fromJson(json).groups;
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Schedule list: ${e.message}');
    }
  }

  /// The days, rounding intervals, tolerances and break lengths HR can choose.
  Future<ScheduleOptions> options() async {
    final json = await _transport.getJson('schedules/options');
    try {
      return ScheduleOptions.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Schedule options: ${e.message}');
    }
  }
}
