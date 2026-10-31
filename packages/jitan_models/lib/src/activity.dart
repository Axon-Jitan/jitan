import 'json_reading.dart';

/// What the day is spent on from a moment on (D19, D22). Each is one
/// `tblTimeRegType` row ("Activity – …"); only [transport] is not working time.
enum ActivityKind {
  work('work'),
  clientOnSite('client_on_site'),
  clientInHouse('client_in_house'),
  internal('internal'),
  transport('transport');

  const ActivityKind(this.wireName);

  final String wireName;

  static ActivityKind fromWire(String value) => values.firstWhere(
    (k) => k.wireName == value,
    orElse: () => throw FormatException('Unknown activity "$value".'),
  );
}

/// A project an employee can work on.
class MyProject {
  const MyProject({
    required this.id,
    required this.name,
    required this.companyId,
    required this.companyName,
    required this.isClient,
    required this.isCurrent,
  });

  factory MyProject.fromJson(Map<String, Object?> json) => MyProject(
    id: json.readInt('id'),
    name: json.readString('name'),
    companyId: json.readInt('companyId'),
    companyName: json.readString('companyName'),
    isClient: json.readBool('isClient'),
    isCurrent: json.readBool('isCurrent'),
  );

  final int id;
  final String name;
  final int companyId;
  final String companyName;
  final bool isClient;

  /// Assigned now; `false` for a project they worked on before.
  final bool isCurrent;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'companyId': companyId,
    'companyName': companyName,
    'isClient': isClient,
    'isCurrent': isCurrent,
  };
}

/// A company an employee can register time for.
class MyCompany {
  const MyCompany({required this.id, required this.name, required this.isDefault});

  factory MyCompany.fromJson(Map<String, Object?> json) =>
      MyCompany(id: json.readInt('id'), name: json.readString('name'), isDefault: json.readBool('isDefault'));

  final int id;
  final String name;
  final bool isDefault;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'isDefault': isDefault};
}

/// What the employee is on right now.
class CurrentActivity {
  const CurrentActivity({required this.kind, required this.since, this.project, this.company});

  factory CurrentActivity.fromJson(Map<String, Object?> json) => CurrentActivity(
    kind: ActivityKind.fromWire(json.readString('kind')),
    since: DateTime.parse(json.readString('since')).toUtc(),
    project: json['project'] == null ? null : MyProject.fromJson(json.readObject('project')),
    company: json['company'] == null ? null : MyCompany.fromJson(json.readObject('company')),
  );

  final ActivityKind kind;
  final DateTime since;
  final MyProject? project;
  final MyCompany? company;

  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    'since': since.toUtc().toIso8601String(),
    'project': project?.toJson(),
    'company': company?.toJson(),
  };
}

/// `GET /me/activity`. [enabled] is `false` on a database without the proposed
/// tables: the app then shows no project card.
class MyActivity {
  const MyActivity({required this.enabled, required this.projects, required this.companies, this.current});

  factory MyActivity.fromJson(Map<String, Object?> json) => MyActivity(
    enabled: json.readBool('enabled'),
    current: json['current'] == null ? null : CurrentActivity.fromJson(json.readObject('current')),
    projects: json.readObjectList('projects').map(MyProject.fromJson).toList(),
    companies: json.readObjectList('companies').map(MyCompany.fromJson).toList(),
  );

  static const disabled = MyActivity(enabled: false, projects: [], companies: []);

  final bool enabled;
  final CurrentActivity? current;

  /// Assigned now, and the ones worked on before.
  final List<MyProject> projects;
  final List<MyCompany> companies;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'current': current?.toJson(),
    'projects': [for (final p in projects) p.toJson()],
    'companies': [for (final c in companies) c.toJson()],
  };
}

/// Body of `POST /me/activity`: "Switching activity does not end your workday."
class SwitchActivityRequest {
  const SwitchActivityRequest({required this.kind, required this.at, this.projectId, this.companyId});

  factory SwitchActivityRequest.fromJson(Map<String, Object?> json) {
    final at = json.readString(fieldAt);
    // A moment, not a wall-clock time: it must say its offset (Z or ±hh:mm).
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(at)) {
      throw const FormatException('"at" must be a moment with an offset.');
    }
    return SwitchActivityRequest(
      kind: ActivityKind.fromWire(json.readString('kind')),
      at: DateTime.parse(at).toUtc(),
      projectId: json.readOptionalInt(fieldProject),
      companyId: json.readOptionalInt(fieldCompany),
    );
  }

  static const fieldAt = 'at';
  static const fieldKind = 'kind';
  static const fieldProject = 'projectId';
  static const fieldCompany = 'companyId';

  final ActivityKind kind;
  final DateTime at;
  final int? projectId;
  final int? companyId;

  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    'at': at.toUtc().toIso8601String(),
    'projectId': projectId,
    'companyId': companyId,
  };
}
