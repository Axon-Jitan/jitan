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

  static ActivityKind fromWire(String value) =>
      values.firstWhere((k) => k.wireName == value, orElse: () => throw FormatException('Unknown activity "$value".'));
}

/// A project an employee can choose (D43, D44): every active project, the
/// ones they used most recently first. Its [id] is its `tblAddress` row.
class MyProject {
  const MyProject({required this.id, required this.name, required this.isClient, this.placeName, this.lastUsed});

  factory MyProject.fromJson(Map<String, Object?> json) => MyProject(
    id: json.readInt('id'),
    name: json.readString('name'),
    isClient: json.readBool('isClient'),
    placeName: json.readOptionalString('placeName'),
    lastUsed: json.readOptionalDateTime('lastUsed')?.toUtc(),
  );

  final int id;

  /// "P-1042 Office refurbishment".
  final String name;

  /// At a client site; `false` for internal work at a workshop.
  final bool isClient;

  /// The client site's town, or the workshop's name.
  final String? placeName;

  /// When they last worked on it; `null` for never.
  final DateTime? lastUsed;

  /// Shown under "Recent" (Figma `1512:502`).
  bool get isRecent => lastUsed != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'isClient': isClient,
    'placeName': placeName,
    'lastUsed': lastUsed?.toUtc().toIso8601String(),
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

/// Work time on one project today (Figma `1606:128`).
class ProjectMinutes {
  const ProjectMinutes({required this.name, required this.minutes});

  factory ProjectMinutes.fromJson(Map<String, Object?> json) =>
      ProjectMinutes(name: json.readString('name'), minutes: json.readInt('minutes'));

  final String name;
  final int minutes;

  Map<String, Object?> toJson() => {'name': name, 'minutes': minutes};
}

/// How today has gone so far (Figma "Today's breakdown"), in minutes.
class ActivityBreakdown {
  const ActivityBreakdown({
    this.clientMinutes = 0,
    this.internalMinutes = 0,
    this.otherMinutes = 0,
    this.transportMinutes = 0,
    this.trips = 0,
    this.distanceMetres = 0,
    this.tripsWithoutDistance = 0,
    this.projects = const [],
  });

  factory ActivityBreakdown.fromJson(Map<String, Object?> json) => ActivityBreakdown(
    clientMinutes: json.readInt('clientMinutes'),
    internalMinutes: json.readInt('internalMinutes'),
    otherMinutes: json.readInt('otherMinutes'),
    transportMinutes: json.readInt('transportMinutes'),
    trips: json.readInt('trips'),
    distanceMetres: json.readOptionalInt('distanceMetres') ?? 0,
    tripsWithoutDistance: json.readOptionalInt('tripsWithoutDistance') ?? 0,
    projects: json['projects'] == null ? const [] : json.readObjectList('projects').map(ProjectMinutes.fromJson).toList(),
  );

  final int clientMinutes;
  final int internalMinutes;
  final int otherMinutes;
  final int transportMinutes;
  final int trips;

  /// The normal route of each trip (D23), calculated by the server.
  final int distanceMetres;

  /// Trips whose place or route isn't known: [distanceMetres] leaves them out.
  final int tripsWithoutDistance;

  /// Work time per project today (transport left out), most first; the
  /// split of a day spent on one kind of work across several projects.
  final List<ProjectMinutes> projects;

  /// More than one kind of work: worth showing.
  bool get isMixed => [clientMinutes, internalMinutes, otherMinutes, transportMinutes].where((minutes) => minutes > 0).length > 1;

  Map<String, Object?> toJson() => {
    'clientMinutes': clientMinutes,
    'internalMinutes': internalMinutes,
    'otherMinutes': otherMinutes,
    'transportMinutes': transportMinutes,
    'trips': trips,
    'distanceMetres': distanceMetres,
    'tripsWithoutDistance': tripsWithoutDistance,
    if (projects.isNotEmpty) 'projects': [for (final p in projects) p.toJson()],
  };
}

/// One line of today's list. A transport says where it arrives and how far.
class ActivityEntry {
  const ActivityEntry({required this.timeLocal, required this.kind, this.projectName, this.placeName, this.metres});

  factory ActivityEntry.fromJson(Map<String, Object?> json) => ActivityEntry(
    timeLocal: json.readString('timeLocal'),
    kind: ActivityKind.fromWire(json.readString('kind')),
    projectName: json.readOptionalString('projectName'),
    placeName: json.readOptionalString('placeName'),
    metres: json.readOptionalInt('metres'),
  );

  /// Workplace-local `HH:mm`.
  final String timeLocal;
  final ActivityKind kind;
  final String? projectName;
  final String? placeName;

  /// `null` when the distance isn't known.
  final int? metres;

  Map<String, Object?> toJson() => {
    'timeLocal': timeLocal,
    'kind': kind.wireName,
    'projectName': projectName,
    'placeName': placeName,
    'metres': metres,
  };
}

/// `GET /me/activity`. [enabled] is `false` while the activity rows are
/// missing from the Lists page: the app then shows no project card.
class MyActivity {
  const MyActivity({
    required this.enabled,
    required this.projects,
    required this.companies,
    this.current,
    this.breakdown = const ActivityBreakdown(),
    this.today = const [],
  });

  factory MyActivity.fromJson(Map<String, Object?> json) => MyActivity(
    enabled: json.readBool('enabled'),
    current: json['current'] == null ? null : CurrentActivity.fromJson(json.readObject('current')),
    projects: json.readObjectList('projects').map(MyProject.fromJson).toList(),
    companies: json.readObjectList('companies').map(MyCompany.fromJson).toList(),
    breakdown: ActivityBreakdown.fromJson(json.readObject('breakdown')),
    today: json['today'] == null ? const [] : json.readObjectList('today').map(ActivityEntry.fromJson).toList(),
  );

  static const disabled = MyActivity(enabled: false, projects: [], companies: []);

  final bool enabled;
  final CurrentActivity? current;

  /// Every active project, the most recently used first (D43).
  final List<MyProject> projects;

  /// Their companies; the day counts for the default one (D44).
  final List<MyCompany> companies;
  final ActivityBreakdown breakdown;

  /// What the day went on so far, oldest first.
  final List<ActivityEntry> today;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'current': current?.toJson(),
    'projects': [for (final p in projects) p.toJson()],
    'companies': [for (final c in companies) c.toJson()],
    'breakdown': breakdown.toJson(),
    'today': [for (final entry in today) entry.toJson()],
  };
}

/// Body of `POST /me/activity`: "Switching activity does not end your workday."
class SwitchActivityRequest {
  const SwitchActivityRequest({required this.kind, required this.at, this.projectId});

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
    );
  }

  static const fieldAt = 'at';
  static const fieldKind = 'kind';
  static const fieldProject = 'projectId';

  final ActivityKind kind;
  final DateTime at;
  final int? projectId;

  Map<String, Object?> toJson() => {'kind': kind.wireName, 'at': at.toUtc().toIso8601String(), 'projectId': projectId};
}

/// Body of `POST /me/activity/trip` (D40): on Automatic, the employee left one
/// location and stayed at another. The server decides whether that is a trip.
class TripRequest {
  const TripRequest({required this.fromAddressId, required this.toAddressId, required this.leftAt, required this.arrivedAt});

  factory TripRequest.fromJson(Map<String, Object?> json) => TripRequest(
    fromAddressId: json.readInt(fieldFrom),
    toAddressId: json.readInt(fieldTo),
    leftAt: _moment(json, fieldLeftAt),
    arrivedAt: _moment(json, fieldArrivedAt),
  );

  static const fieldFrom = 'fromAddressId';
  static const fieldTo = 'toAddressId';
  static const fieldLeftAt = 'leftAt';
  static const fieldArrivedAt = 'arrivedAt';

  final int fromAddressId;
  final int toAddressId;
  final DateTime leftAt;
  final DateTime arrivedAt;

  /// A moment, not a wall-clock time: it must say its offset.
  static DateTime _moment(Map<String, Object?> json, String field) {
    final value = json.readString(field);
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
      throw FormatException('"$field" must be a moment with an offset.');
    }
    return DateTime.parse(value).toUtc();
  }

  Map<String, Object?> toJson() => {
    fieldFrom: fromAddressId,
    fieldTo: toAddressId,
    fieldLeftAt: leftAt.toUtc().toIso8601String(),
    fieldArrivedAt: arrivedAt.toUtc().toIso8601String(),
  };
}
