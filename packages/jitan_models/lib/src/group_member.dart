import 'json_reading.dart';

/// An employee as the group page shows them (`GET /groups/{id}/members`
/// and `…/candidates`): who they are, the companies they work for and every
/// group they are in. Groups are shared by all companies, so a group's
/// members can come from any company (product owner, 2026-10-21).
class GroupMember {
  const GroupMember({
    required this.id,
    required this.code,
    required this.companies,
    required this.groups,
    this.firstName,
    this.lastName,
  });

  factory GroupMember.fromJson(Map<String, Object?> json) => GroupMember(
        id: json.readInt('id'),
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        code: json.readString('code'),
        companies: json.readStringList('companies'),
        groups: json.readStringList('groups'),
      );

  /// `tblUser.userID`.
  final int id;

  /// `userName` (the first name) and `userSurname`.
  final String? firstName;
  final String? lastName;

  /// `userCode`, the employee code.
  final String code;

  /// Names of the companies the employee currently belongs to.
  final List<String> companies;

  /// Names of every group the employee is currently in (this one included
  /// for a member).
  final List<String> groups;

  String get displayName => [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  Map<String, Object?> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'companies': companies,
        'groups': groups,
      };
}

/// Response body of `GET /groups/{id}/members` and `…/candidates`.
class GroupMemberListResponse {
  const GroupMemberListResponse({required this.members});

  factory GroupMemberListResponse.fromJson(Map<String, Object?> json) =>
      GroupMemberListResponse(members: json.readObjectList('members').map(GroupMember.fromJson).toList());

  final List<GroupMember> members;

  Map<String, Object?> toJson() => {
        'members': [for (final member in members) member.toJson()],
      };
}
