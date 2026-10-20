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

  /// Sets a group's work hours, replacing any it had; the group's schedule
  /// as it is afterwards.
  Future<GroupSchedule> setWorkHours(int groupId, SetWorkHoursRequest request) async =>
      _group(await _transport.putJson('schedules/groups/$groupId/work-hours', request.toJson()));

  /// Removes a group's work hours.
  Future<GroupSchedule> removeWorkHours(int groupId) async =>
      _group(await _transport.deleteJson('schedules/groups/$groupId/work-hours'));

  /// Sets a group's breaks, replacing any it had.
  Future<GroupSchedule> setBreaks(int groupId, SetBreaksRequest request) async =>
      _group(await _transport.putJson('schedules/groups/$groupId/breaks', request.toJson()));

  /// Removes a group's breaks.
  Future<GroupSchedule> removeBreaks(int groupId) async =>
      _group(await _transport.deleteJson('schedules/groups/$groupId/breaks'));

  static GroupSchedule _group(Map<String, Object?> json) {
    try {
      return GroupSchedule.fromJson(json);
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, 'Group schedule: ${e.message}');
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
