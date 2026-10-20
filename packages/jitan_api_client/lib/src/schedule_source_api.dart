import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// "Schedules come from" (HR/Admin, company-scoped): which of an employee's
/// groups their schedule comes from, for employees in several groups.
class ScheduleSourceApi {
  const ScheduleSourceApi(this._transport);

  final ApiTransport _transport;

  Future<ScheduleSourceResponse> get(int companyId, int userId) async =>
      _parse(await _transport.getJson(_path(companyId, userId)));

  Future<ScheduleSourceResponse> set(int companyId, int userId, int groupId) async =>
      _parse(await _transport.putJson(_path(companyId, userId), ScheduleSourceRequest(groupId: groupId).toJson()));

  static String _path(int companyId, int userId) =>
      'companies/$companyId/employees/$userId/assignments/schedule-source';

  static ScheduleSourceResponse _parse(Map<String, Object?> json) {
    try {
      return ScheduleSourceResponse.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Schedule source: ${e.message}');
    }
  }
}
