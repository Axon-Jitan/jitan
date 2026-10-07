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
