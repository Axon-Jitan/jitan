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
    this.companyIds = const [],
    this.hoursFromGroupId,
    this.hoursFromGroup,
  });

  factory GroupMember.fromJson(Map<String, Object?> json) => GroupMember(
        id: json.readInt('id'),
        firstName: json.readOptionalString('firstName'),
        lastName: json.readOptionalString('lastName'),
        code: json.readString('code'),
        companies: json.readStringList('companies'),
        groups: json.readStringList('groups'),
        companyIds: json['companyIds'] == null ? const [] : json.readIntList('companyIds'),
        hoursFromGroupId: json.readOptionalInt('hoursFromGroupId'),
        hoursFromGroup: json.readOptionalString('hoursFromGroup'),
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

  /// The ids of [companies], in the same order: company-scoped actions
  /// such as "Schedules come from" are made in one of them.
  final List<int> companyIds;

  /// The group the employee's work hours come from (members only); `null`
  /// without hours, or when they are not exactly one group's (HR chooses).
  final int? hoursFromGroupId;
  final String? hoursFromGroup;

  String get displayName => [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ');

  Map<String, Object?> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'code': code,
        'companies': companies,
        'groups': groups,
        if (companyIds.isNotEmpty) 'companyIds': companyIds,
        'hoursFromGroupId': hoursFromGroupId,
        'hoursFromGroup': hoursFromGroup,
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

/// Body of `POST /groups/{id}/members` (Figma `1390:1106`): the employees to
/// add, and of those already in other groups, the ones who "Use {group}
/// hours" ([followIds]); the others keep their current hours.
class AddGroupMembersRequest {
  const AddGroupMembersRequest({required this.ids, this.followIds = const []});

  factory AddGroupMembersRequest.fromJson(Map<String, Object?> json) => AddGroupMembersRequest(
    ids: json.readIntList(fieldIds),
    followIds: json[fieldFollowIds] == null ? const [] : json.readIntList(fieldFollowIds),
  );

  final List<int> ids;
  final List<int> followIds;

  static const fieldIds = 'ids';
  static const fieldFollowIds = 'followIds';

  Map<String, Object?> toJson() => {fieldIds: ids, if (followIds.isNotEmpty) fieldFollowIds: followIds};
}
