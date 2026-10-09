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
    this.groupId,
    this.phone,
  });

  factory CreateEmployeeRequest.fromJson(Map<String, Object?> json) => CreateEmployeeRequest(
        firstName: json.readString('firstName'),
        lastName: json.readString('lastName'),
        code: json.readString('code'),
        groupId: json.readOptionalInt('groupId'),
        phone: json.readOptionalString('phone'),
      );

  /// `tblUser.userName`.
  final String firstName;

  /// `tblUser.userSurname`.
  final String lastName;

  /// `tblUser.userCode`, unique across all users.
  final String code;

  /// `tblGroup.groupID` ("Employee type"), linked through `tblUserGroup`.
  final int? groupId;

  /// `tblUser.cellphoneNumber`.
  final String? phone;

  /// Field names, for [ApiError.field].
  static const fieldFirstName = 'firstName';
  static const fieldLastName = 'lastName';
  static const fieldCode = 'code';
  static const fieldGroupId = 'groupId';
  static const fieldPhone = 'phone';

  /// Longest values the database stores, in characters (Unicode code points,
  /// as MySQL counts them: use `value.runes.length`). From IT's `tblUser`:
  /// `userName`/`userSurname` VARCHAR(100), `userCode` VARCHAR(50),
  /// `cellphoneNumber` VARCHAR(30).
  static const maxFirstNameLength = 100;
  static const maxLastNameLength = 100;
  static const maxCodeLength = 50;
  static const maxPhoneLength = 30;

  Map<String, Object?> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'groupId': groupId,
        'phone': phone,
      };
}
