import 'json_reading.dart';
import 'schedule.dart';

/// One row of the HR/Admin Employees list for a company.
///
/// Sources (see docs/database/ERD.md):
/// - [id], [firstName], [lastName], [code], [isActive]: `tblUser`
///   (`userName` is the first name, `userSurname` the last name)
/// - [groups]: names of the user's active `tblGroup` rows via `tblUserGroup`,
///   the "Type" column. Every group is listed; no priority is applied.
///
/// - [isActivated]: onboarding completed, i.e. `userPassword IS NOT NULL`
///   (decision 2026-10-07). Only this flag leaves the server, never the hash.
/// - [schedule]: the hours the employee currently has (`tblUserSchedule`),
///   the "Schedule" column (Figma `1401:2`); `null` without hours.
/// - [companyIds]: the listed companies the employee belongs to
///   (`tblUserCompany`), so an action can be taken in one of them when the
///   list shows every company.
///
/// Not included: location (ERD GAP-11), policy
/// (PRODUCT-CLARIFY-EMPLOYEE-POLICY).
class EmployeeSummary {
  const EmployeeSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.code,
    required this.groups,
    required this.isActive,
    required this.isActivated,
    this.schedule,
    this.companyIds = const [],
  });

  factory EmployeeSummary.fromJson(Map<String, Object?> json) => EmployeeSummary(
        id: json.readInt('id'),
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        code: json.readString('code'),
        groups: json.readStringList('groups'),
        isActive: json.readBool('isActive'),
        isActivated: json.readBool('isActivated'),
        schedule: json['schedule'] == null ? null : ScheduleVariant.fromJson(json.readObject('schedule')),
        companyIds: json['companyIds'] == null ? const [] : json.readIntList('companyIds'),
      );

  final int id;
  final String? firstName;
  final String? lastName;

  /// `tblUser.userCode`, the employee code used to sign in.
  final String code;
  final List<String> groups;
  final bool isActive;

  /// Onboarding completed (`userPassword IS NOT NULL`).
  final bool isActivated;

  final ScheduleVariant? schedule;
  final List<int> companyIds;

  /// The same employee with [schedule].
  EmployeeSummary withSchedule(ScheduleVariant? schedule) => EmployeeSummary(
        id: id,
        firstName: firstName,
        lastName: lastName,
        code: code,
        groups: groups,
        isActive: isActive,
        isActivated: isActivated,
        schedule: schedule,
        companyIds: companyIds,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'groups': groups,
        'isActive': isActive,
        'isActivated': isActivated,
        if (schedule case final schedule?) 'schedule': schedule.toJson(),
        if (companyIds.isNotEmpty) 'companyIds': companyIds,
      };
}

/// Response body of `GET /companies/{companyId}/employees`, and of
/// `GET /employees` (every company the viewer may see; [companyId] `null`).
class EmployeeListResponse {
  const EmployeeListResponse({required this.companyId, required this.employees});

  factory EmployeeListResponse.fromJson(Map<String, Object?> json) => EmployeeListResponse(
        companyId: json.readOptionalInt('companyId'),
        employees: json.readObjectList('employees').map(EmployeeSummary.fromJson).toList(),
      );

  final int? companyId;
  final List<EmployeeSummary> employees;

  Map<String, Object?> toJson() => {
        'companyId': companyId,
        'employees': [for (final employee in employees) employee.toJson()],
      };
}
