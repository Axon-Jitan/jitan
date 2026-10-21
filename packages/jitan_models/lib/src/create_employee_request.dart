import 'json_reading.dart';

/// Body of `POST /companies/{companyId}/employees`.
///
/// Only fields the fixed ERD can store (see docs/database/ERD.md). Location
/// (ERD GAP-11) and work policy (PRODUCT-CLARIFY-EMPLOYEE-POLICY) are not
/// part of it.
class CreateEmployeeRequest {
  const CreateEmployeeRequest({
    required this.firstName,
    required this.lastName,
    required this.code,
    this.phone,
    this.email,
    this.companyIds = const [],
    this.groupIds = const [],
    this.scheduleGroupId,
  });

  factory CreateEmployeeRequest.fromJson(Map<String, Object?> json) => CreateEmployeeRequest(
        firstName: json.readString(fieldFirstName),
        lastName: json.readString(fieldLastName),
        code: json.readString(fieldCode),
        phone: json.readOptionalString(fieldPhone),
        email: json.readOptionalString(fieldEmail),
        companyIds: json[fieldCompanyIds] == null ? const [] : json.readIntList(fieldCompanyIds),
        groupIds: json[fieldGroupIds] == null ? const [] : json.readIntList(fieldGroupIds),
        scheduleGroupId: json.readOptionalInt(fieldScheduleGroupId),
      );

  /// `tblUser.userName`.
  final String firstName;

  /// `tblUser.userSurname`.
  final String lastName;

  /// `tblUser.userCode`, unique across all users.
  final String code;

  /// `tblUser.cellphoneNumber`.
  final String? phone;

  /// `tblUser.userEmail` (optional; never used to sign in).
  final String? email;

  /// Companies besides the one in the path (`tblUserCompany`), Add employee
  /// step 2 "Companies" (Figma `985:2`).
  final List<int> companyIds;

  /// `tblGroup.groupID`s, linked through `tblUserGroup`: step 2 "Employee
  /// groups" (the employee type, e.g. White collar, is one of them).
  final List<int> groupIds;

  /// Step 2 "Work schedule": the group (one of [groupIds]) whose hours the
  /// employee follows. Needed only with several groups; with one group the
  /// employee follows it anyway.
  final int? scheduleGroupId;

  /// Field names, for [ApiError.field].
  static const fieldFirstName = 'firstName';
  static const fieldLastName = 'lastName';
  static const fieldCode = 'code';
  static const fieldPhone = 'phone';
  static const fieldEmail = 'email';
  static const fieldCompanyIds = 'companyIds';
  static const fieldGroupIds = 'groupIds';
  static const fieldScheduleGroupId = 'scheduleGroupId';

  /// Longest values the database stores, in characters (Unicode code points,
  /// as MySQL counts them: use `value.runes.length`). From IT's `tblUser`:
  /// `userName`/`userSurname` VARCHAR(100), `userCode` VARCHAR(50),
  /// `cellphoneNumber` VARCHAR(30), `userEmail` VARCHAR(255).
  static const maxFirstNameLength = 100;
  static const maxLastNameLength = 100;
  static const maxCodeLength = 50;
  static const maxPhoneLength = 30;
  static const maxEmailLength = 255;

  Map<String, Object?> toJson() => {
        fieldFirstName: firstName,
        fieldLastName: lastName,
        fieldCode: code,
        fieldPhone: phone,
        fieldEmail: email,
        if (companyIds.isNotEmpty) fieldCompanyIds: companyIds,
        if (groupIds.isNotEmpty) fieldGroupIds: groupIds,
        fieldScheduleGroupId: scheduleGroupId,
      };
}
