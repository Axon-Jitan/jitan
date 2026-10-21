import 'group_summary.dart';
import 'json_reading.dart';
import 'schedule_requests.dart';

/// Body of `POST /groups`: Create group's three steps saved together (Figma
/// `HR / Employee groups — Create group`): the name, the employees from
/// every company, and the work hours and break. The server writes all of it
/// in one transaction.
///
/// Every group has work hours (product owner, 2026-10-21). The ERD keeps
/// them on the employees whose only group is the new one, so at least one
/// of [employeeIds] must be in no other group.
class CreateGroupRequest {
  const CreateGroupRequest({required this.name, required this.employeeIds, required this.schedule});

  factory CreateGroupRequest.fromJson(Map<String, Object?> json) => CreateGroupRequest(
    name: json.readString(fieldName),
    employeeIds: json.readIntList(fieldEmployeeIds),
    schedule: SetGroupScheduleRequest.fromJson(json.readObject(fieldSchedule)),
  );

  final String name;
  final List<int> employeeIds;
  final SetGroupScheduleRequest schedule;

  static const fieldName = GroupNameRequest.fieldName;
  static const fieldEmployeeIds = 'employeeIds';
  static const fieldSchedule = 'schedule';

  Map<String, Object?> toJson() => {fieldName: name, fieldEmployeeIds: employeeIds, fieldSchedule: schedule.toJson()};
}
