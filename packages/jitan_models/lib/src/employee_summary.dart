import 'json_reading.dart';

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
  });

  factory EmployeeSummary.fromJson(Map<String, Object?> json) => EmployeeSummary(
        id: json.readInt('id'),
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        code: json.readString('code'),
        groups: json.readStringList('groups'),
        isActive: json.readBool('isActive'),
        isActivated: json.readBool('isActivated'),
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

  Map<String, Object?> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'groups': groups,
        'isActive': isActive,
        'isActivated': isActivated,
      };
}

/// Response body of `GET /companies/{companyId}/employees`.
class EmployeeListResponse {
  const EmployeeListResponse({required this.companyId, required this.employees});

  factory EmployeeListResponse.fromJson(Map<String, Object?> json) => EmployeeListResponse(
        companyId: json.readInt('companyId'),
        employees: json.readObjectList('employees').map(EmployeeSummary.fromJson).toList(),
      );

  final int companyId;
  final List<EmployeeSummary> employees;

  Map<String, Object?> toJson() => {
        'companyId': companyId,
        'employees': [for (final employee in employees) employee.toJson()],
      };
}
