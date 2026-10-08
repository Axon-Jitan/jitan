import 'json_reading.dart';

/// One choice on a "Manage employee assignments" tab (a company, group or
/// credential group) and whether the employee already has it.
class AssignmentOption {
  const AssignmentOption({required this.id, required this.name, required this.isActive, required this.isAssigned});

  factory AssignmentOption.fromJson(Map<String, Object?> json) => AssignmentOption(
        id: json.readInt('id'),
        name: json.readString('name'),
        isActive: json.readBool('isActive'),
        isAssigned: json.readBool('isAssigned'),
      );

  final int id;
  final String name;

  /// Only active options can be newly assigned. An inactive one is listed
  /// only when the employee already has it.
  final bool isActive;
  final bool isAssigned;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'isActive': isActive, 'isAssigned': isAssigned};
}

/// Response of the assignment endpoints: every option, assigned or not.
class AssignmentOptions {
  const AssignmentOptions({required this.options});

  factory AssignmentOptions.fromJson(Map<String, Object?> json) =>
      AssignmentOptions(options: [for (final o in json.readObjectList('options')) AssignmentOption.fromJson(o)]);

  final List<AssignmentOption> options;

  Map<String, Object?> toJson() => {'options': [for (final o in options) o.toJson()]};
}

/// Body of `POST …/assignments/<kind>`: options to **add**. Assignments are
/// never removed through Jitan until IT confirms how junction rows may be
/// deleted.
class AddAssignmentsRequest {
  const AddAssignmentsRequest({required this.ids});

  factory AddAssignmentsRequest.fromJson(Map<String, Object?> json) =>
      AddAssignmentsRequest(ids: json.readIntList('ids'));

  final List<int> ids;

  static const fieldIds = 'ids';

  Map<String, Object?> toJson() => {'ids': ids};
}
