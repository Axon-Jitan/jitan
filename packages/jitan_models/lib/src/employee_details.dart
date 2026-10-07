import 'json_reading.dart';

/// One employee as shown in the HR/Admin "Employee details" modal, within a
/// company. Response of `GET /companies/{companyId}/employees/{userId}`.
///
/// Sources: `tblUser` (names, code, phone, status), `tblUserGroup` →
/// `tblGroup` (groups, all of them, no priority), `tblCompany` (name).
///
/// Not included: location (ERD GAP-11), work policy
/// (PRODUCT-CLARIFY-EMPLOYEE-POLICY). Never the password, PIN or QR: only
/// [isActivated] (`userPassword IS NOT NULL`).
class EmployeeDetails {
  const EmployeeDetails({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.firstName,
    required this.lastName,
    required this.code,
    required this.groups,
    required this.phone,
    required this.isActive,
    required this.isActivated,
  });

  factory EmployeeDetails.fromJson(Map<String, Object?> json) => EmployeeDetails(
        id: json.readInt('id'),
        companyId: json.readInt('companyId'),
        companyName: json.readString('companyName'),
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        code: json.readString('code'),
        groups: json.readStringList('groups'),
        phone: json.readOptionalString('phone'),
        isActive: json.readBool('isActive'),
        isActivated: json.readBool('isActivated'),
      );

  final int id;
  final int companyId;
  final String companyName;
  final String? firstName;
  final String? lastName;
  final String code;
  final List<String> groups;
  final String? phone;
  final bool isActive;

  /// Onboarding completed (`userPassword IS NOT NULL`).
  final bool isActivated;

  Map<String, Object?> toJson() => {
        'id': id,
        'companyId': companyId,
        'companyName': companyName,
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'groups': groups,
        'phone': phone,
        'isActive': isActive,
        'isActivated': isActivated,
      };
}
