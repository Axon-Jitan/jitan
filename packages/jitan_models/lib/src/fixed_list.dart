import 'json_reading.dart';

/// The fixed lists on the Lists page (Figma `1510:2`). Jitan reads the
/// entries of most of them by name, so it knows which it needs; the others
/// (access roles, languages) are free and only counted.
enum FixedListKind {
  registrationTypes('registration_types'),
  scheduleTypes('schedule_types'),
  days('days'),
  accessRoles('access_roles'),
  languages('languages'),
  placeKinds('place_kinds'),
  terminalKinds('terminal_kinds'),
  auditNames('audit_names');

  const FixedListKind(this.wireName);

  final String wireName;

  static FixedListKind? fromWire(String value) => values.where((k) => k.wireName == value).firstOrNull;
}

/// One list in `GET /lists`.
class FixedListSummary {
  const FixedListSummary({required this.kind, required this.entries, required this.required, required this.missing});

  factory FixedListSummary.fromJson(Map<String, Object?> json) => FixedListSummary(
    kind: FixedListKind.fromWire(json.readString('kind')) ?? (throw FormatException('Unknown list "${json['kind']}".')),
    entries: json.readInt('entries'),
    required: json.readInt('required'),
    missing: json.readInt('missing'),
  );

  final FixedListKind kind;

  /// Active entries the list has now.
  final int entries;

  /// How many entries Jitan needs; 0 for a free list.
  final int required;
  final int missing;

  bool get isReady => missing == 0;

  Map<String, Object?> toJson() => {'kind': kind.wireName, 'entries': entries, 'required': required, 'missing': missing};
}

/// `GET /lists`.
class FixedListOverview {
  const FixedListOverview({required this.lists});

  factory FixedListOverview.fromJson(Map<String, Object?> json) =>
      FixedListOverview(lists: json.readObjectList('lists').map(FixedListSummary.fromJson).toList());

  final List<FixedListSummary> lists;

  int get listsMissing => lists.where((l) => !l.isReady).length;

  Map<String, Object?> toJson() => {
    'lists': [for (final list in lists) list.toJson()],
  };
}

/// One entry of a list: [present] when the database has it, [required]
/// when Jitan reads it by name.
class FixedListEntry {
  const FixedListEntry({required this.name, required this.present, required this.required});

  factory FixedListEntry.fromJson(Map<String, Object?> json) =>
      FixedListEntry(name: json.readString('name'), present: json.readBool('present'), required: json.readBool('required'));

  final String name;
  final bool present;
  final bool required;

  Map<String, Object?> toJson() => {'name': name, 'present': present, 'required': required};
}

/// `GET /lists/{kind}`: what Jitan needs first, in its own order, then what
/// else the list holds.
class FixedListDetail {
  const FixedListDetail({required this.kind, required this.entries});

  factory FixedListDetail.fromJson(Map<String, Object?> json) => FixedListDetail(
    kind: FixedListKind.fromWire(json.readString('kind')) ?? (throw FormatException('Unknown list "${json['kind']}".')),
    entries: json.readObjectList('entries').map(FixedListEntry.fromJson).toList(),
  );

  final FixedListKind kind;
  final List<FixedListEntry> entries;

  int get missing => entries.where((e) => !e.present).length;

  Map<String, Object?> toJson() => {
    'kind': kind.wireName,
    'entries': [for (final entry in entries) entry.toJson()],
  };
}
