import 'json_reading.dart';

/// An active `tblGroup` row: an employee grouping such as Blue collar /
/// White collar (the "Employee type").
class GroupSummary {
  const GroupSummary({required this.id, required this.name});

  factory GroupSummary.fromJson(Map<String, Object?> json) =>
      GroupSummary(id: json.readInt('id'), name: json.readString('name'));

  final int id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

/// Response body of `GET /groups`.
class GroupListResponse {
  const GroupListResponse({required this.groups});

  factory GroupListResponse.fromJson(Map<String, Object?> json) =>
      GroupListResponse(groups: json.readObjectList('groups').map(GroupSummary.fromJson).toList());

  final List<GroupSummary> groups;

  Map<String, Object?> toJson() => {
        'groups': [for (final group in groups) group.toJson()],
      };
}

/// One employee group as HR/Admin manage it: active or not, with how many
/// employees are in it.
class GroupOverview {
  const GroupOverview({required this.id, required this.name, required this.isActive, required this.employeeCount});

  factory GroupOverview.fromJson(Map<String, Object?> json) => GroupOverview(
        id: json.readInt('id'),
        name: json.readString('name'),
        isActive: json.readBool('isActive'),
        employeeCount: json.readInt('employeeCount'),
      );

  final int id;
  final String name;
  final bool isActive;

  /// Employees currently in the group (not marked for deletion).
  final int employeeCount;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'isActive': isActive, 'employeeCount': employeeCount};
}

/// Response body of `GET /groups/overview`.
class GroupOverviewListResponse {
  const GroupOverviewListResponse({required this.groups});

  factory GroupOverviewListResponse.fromJson(Map<String, Object?> json) =>
      GroupOverviewListResponse(groups: json.readObjectList('groups').map(GroupOverview.fromJson).toList());

  final List<GroupOverview> groups;

  Map<String, Object?> toJson() => {
        'groups': [for (final group in groups) group.toJson()],
      };
}

/// Body of `POST /groups` (add) and `PUT /groups/{id}` (rename).
class GroupNameRequest {
  const GroupNameRequest({required this.name});

  factory GroupNameRequest.fromJson(Map<String, Object?> json) => GroupNameRequest(name: json.readString(fieldName));

  final String name;

  static const fieldName = 'name';

  /// `tblGroup.groupName` is VARCHAR(100) in IT's database; characters as
  /// MySQL counts them (`name.runes.length`).
  static const maxNameLength = 100;

  Map<String, Object?> toJson() => {fieldName: name};
}
