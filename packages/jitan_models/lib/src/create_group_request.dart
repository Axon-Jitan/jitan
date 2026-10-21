import 'group_summary.dart';
import 'json_reading.dart';
import 'schedule_requests.dart';

/// Body of `POST /groups`: Create group's three steps saved together (Figma
/// `HR / Employee groups — Create group`): the name, the employees from
/// every company, and the work hours and break. The server writes all of it
/// in one transaction.
///
/// Employees and work hours are optional (product owner, 2026-10-21): HR
/// may create an empty group and fill it later. Without the proposed
/// group–schedule link (ERD_GAPS GAP-15) the hours are kept on the employees
/// whose only group is the new one, so hours then need one of them among
/// [employeeIds].
class CreateGroupRequest {
  const CreateGroupRequest({required this.name, this.employeeIds = const [], this.schedule});

  factory CreateGroupRequest.fromJson(Map<String, Object?> json) => CreateGroupRequest(
    name: json.readString(fieldName),
    employeeIds: json[fieldEmployeeIds] == null ? const [] : json.readIntList(fieldEmployeeIds),
    schedule: json[fieldSchedule] == null ? null : SetGroupScheduleRequest.fromJson(json.readObject(fieldSchedule)),
  );

  final String name;
  final List<int> employeeIds;
  final SetGroupScheduleRequest? schedule;

  static const fieldName = GroupNameRequest.fieldName;
  static const fieldEmployeeIds = 'employeeIds';
  static const fieldSchedule = 'schedule';

  Map<String, Object?> toJson() => {
    fieldName: name,
    if (employeeIds.isNotEmpty) fieldEmployeeIds: employeeIds,
    if (schedule case final schedule?) fieldSchedule: schedule.toJson(),
  };
}
