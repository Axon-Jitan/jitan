import 'json_reading.dart';
import 'time_record.dart';

/// One row of a project lookup (`tblProjectType`, `tblProjectStatus`).
class ProjectChoice {
  const ProjectChoice({required this.id, required this.name});

  factory ProjectChoice.fromJson(Map<String, Object?> json) =>
      ProjectChoice(id: json.readInt('id'), name: json.readString('name'));

  final int id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

/// The project form's choices. A type with [ProjectChoice.id] in
/// [addressTypeIds] needs a client address.
class ProjectOptions {
  const ProjectOptions({required this.types, required this.statuses, required this.addressTypeIds});

  factory ProjectOptions.fromJson(Map<String, Object?> json) => ProjectOptions(
    types: json.readObjectList('types').map(ProjectChoice.fromJson).toList(),
    statuses: json.readObjectList('statuses').map(ProjectChoice.fromJson).toList(),
    addressTypeIds: json.readIntList('addressTypeIds'),
  );

  final List<ProjectChoice> types;
  final List<ProjectChoice> statuses;
  final List<int> addressTypeIds;

  Map<String, Object?> toJson() => {
    'types': [for (final t in types) t.toJson()],
    'statuses': [for (final s in statuses) s.toJson()],
    'addressTypeIds': addressTypeIds,
  };
}

/// One row of the Projects list.
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.companyId,
    required this.companyName,
    required this.type,
    required this.status,
    required this.teamSize,
    this.reference,
  });

  factory ProjectSummary.fromJson(Map<String, Object?> json) => ProjectSummary(
    id: json.readInt('id'),
    name: json.readString('name'),
    reference: json.readOptionalString('reference'),
    companyId: json.readInt('companyId'),
    companyName: json.readString('companyName'),
    type: ProjectChoice.fromJson(json.readObject('type')),
    status: ProjectChoice.fromJson(json.readObject('status')),
    teamSize: json.readInt('teamSize'),
  );

  final int id;
  final String name;
  final String? reference;
  final int companyId;
  final String companyName;
  final ProjectChoice type;
  final ProjectChoice status;
  final int teamSize;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'reference': reference,
    'companyId': companyId,
    'companyName': companyName,
    'type': type.toJson(),
    'status': status.toJson(),
    'teamSize': teamSize,
  };
}

class ProjectListResponse {
  const ProjectListResponse({required this.projects});

  factory ProjectListResponse.fromJson(Map<String, Object?> json) =>
      ProjectListResponse(projects: json.readObjectList('projects').map(ProjectSummary.fromJson).toList());

  final List<ProjectSummary> projects;

  Map<String, Object?> toJson() => {
    'projects': [for (final p in projects) p.toJson()],
  };
}

/// Someone assigned to a project.
class ProjectEmployee {
  const ProjectEmployee({required this.id, required this.code, this.firstName, this.lastName});

  factory ProjectEmployee.fromJson(Map<String, Object?> json) => ProjectEmployee(
    id: json.readInt('id'),
    code: json.readString('code'),
    firstName: json.readOptionalString('firstName'),
    lastName: json.readOptionalString('lastName'),
  );

  final int id;
  final String code;
  final String? firstName;
  final String? lastName;

  Map<String, Object?> toJson() => {'id': id, 'code': code, 'firstName': firstName, 'lastName': lastName};
}

/// A project's page.
class ProjectDetails {
  const ProjectDetails({
    required this.summary,
    required this.startDate,
    required this.employees,
    this.endDate,
    this.description,
    this.addressId,
    this.addressName,
  });

  factory ProjectDetails.fromJson(Map<String, Object?> json) {
    final end = json.readOptionalString('endDate');
    return ProjectDetails(
      summary: ProjectSummary.fromJson(json),
      startDate: TimeRecordDay.parseDate(json.readString('startDate')),
      endDate: end == null ? null : TimeRecordDay.parseDate(end),
      description: json.readOptionalString('description'),
      addressId: json.readOptionalInt('addressId'),
      addressName: json.readOptionalString('addressName'),
      employees: json.readObjectList('employees').map(ProjectEmployee.fromJson).toList(),
    );
  }

  final ProjectSummary summary;
  final DateTime startDate;
  final DateTime? endDate;
  final String? description;
  final int? addressId;
  final String? addressName;
  final List<ProjectEmployee> employees;

  Map<String, Object?> toJson() => {
    ...summary.toJson(),
    'startDate': TimeRecordDay.dateText(startDate),
    'endDate': endDate == null ? null : TimeRecordDay.dateText(endDate!),
    'description': description,
    'addressId': addressId,
    'addressName': addressName,
    'employees': [for (final e in employees) e.toJson()],
  };
}

/// Body of adding or changing a project. The company comes from the path.
class ProjectRequest {
  const ProjectRequest({
    required this.name,
    required this.typeId,
    required this.statusId,
    required this.startDate,
    this.reference,
    this.endDate,
    this.description,
    this.addressId,
  });

  factory ProjectRequest.fromJson(Map<String, Object?> json) => ProjectRequest(
    name: json.readString('name'),
    typeId: json.readInt('typeId'),
    statusId: json.readInt('statusId'),
    startDate: json.readString('startDate'),
    reference: json.readOptionalString('reference'),
    endDate: json.readOptionalString('endDate'),
    description: json.readOptionalString('description'),
    addressId: json.readOptionalInt('addressId'),
  );

  static const fieldName = 'name';
  static const fieldReference = 'reference';
  static const fieldType = 'typeId';
  static const fieldStatus = 'statusId';
  static const fieldStartDate = 'startDate';
  static const fieldEndDate = 'endDate';
  static const fieldDescription = 'description';
  static const fieldAddress = 'addressId';

  // tblProject's column sizes.
  static const maxNameLength = 150;
  static const maxReferenceLength = 50;
  static const maxDescriptionLength = 500;

  final String name;
  final int typeId;
  final int statusId;

  /// `yyyy-MM-dd`.
  final String startDate;
  final String? endDate;
  final String? reference;
  final String? description;
  final int? addressId;

  ProjectRequest trimmed() {
    String? clean(String? text) {
      final value = text?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    return ProjectRequest(
      name: name.trim(),
      typeId: typeId,
      statusId: statusId,
      startDate: startDate.trim(),
      endDate: clean(endDate),
      reference: clean(reference),
      description: clean(description),
      addressId: addressId,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'typeId': typeId,
    'statusId': statusId,
    'startDate': startDate,
    'endDate': endDate,
    'reference': reference,
    'description': description,
    'addressId': addressId,
  };
}

/// Body of "Save assignments": everyone who should be on the project.
class ProjectEmployeesRequest {
  const ProjectEmployeesRequest({required this.employeeIds});

  factory ProjectEmployeesRequest.fromJson(Map<String, Object?> json) =>
      ProjectEmployeesRequest(employeeIds: json.readIntList('employeeIds'));

  final List<int> employeeIds;

  Map<String, Object?> toJson() => {'employeeIds': employeeIds};
}
