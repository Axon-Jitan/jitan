import 'activity.dart';
import 'json_reading.dart';

/// How HR sees a terminal. Calculated by the server from what it stored.
enum TerminalStatus {
  online('online'),
  offline('offline'),

  /// Added, but no tablet has been connected yet.
  notConnected('not_connected'),

  /// Deactivated by HR: nobody can scan there.
  inactive('inactive');

  const TerminalStatus(this.wireName);

  final String wireName;

  static TerminalStatus fromWire(String value) => values.firstWhere(
    (s) => s.wireName == value,
    orElse: () => throw FormatException('Unknown terminal status "$value".'),
  );
}

/// A kind of terminal: a `tblDeviceType` row such as "Office terminal".
class TerminalTypeChoice {
  const TerminalTypeChoice({required this.id, required this.name});

  factory TerminalTypeChoice.fromJson(Map<String, Object?> json) =>
      TerminalTypeChoice(id: json.readInt('id'), name: json.readString('name'));

  final int id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

/// `GET /terminal-options`. [vehicleTypeIds]: the types that sit in a van, so
/// the form says to put the number plate in the name.
class TerminalOptions {
  const TerminalOptions({required this.types, required this.vehicleTypeIds});

  factory TerminalOptions.fromJson(Map<String, Object?> json) => TerminalOptions(
    types: json.readObjectList('types').map(TerminalTypeChoice.fromJson).toList(),
    vehicleTypeIds: [for (final id in json['vehicleTypeIds']! as List<Object?>) id! as int],
  );

  final List<TerminalTypeChoice> types;
  final List<int> vehicleTypeIds;

  Map<String, Object?> toJson() => {
    'types': [for (final type in types) type.toJson()],
    'vehicleTypeIds': vehicleTypeIds,
  };
}

/// A terminal on the HR page (Figma `1507:2`): a shared tablet (`tblDevice`
/// with `deviceMultiUser = 1`) that employees of every company can use. Never
/// carries its secret.
class Terminal {
  const Terminal({
    required this.id,
    required this.name,
    required this.type,
    required this.serialNumber,
    required this.status,
    this.lastSeen,
    this.lastScan,
    this.connectionTag,
  });

  factory Terminal.fromJson(Map<String, Object?> json) => Terminal(
    id: json.readInt('id'),
    name: json.readString('name'),
    type: TerminalTypeChoice.fromJson(json.readObject('type')),
    serialNumber: json.readString('serialNumber'),
    status: TerminalStatus.fromWire(json.readString('status')),
    lastSeen: json.readOptionalDateTime('lastSeen')?.toUtc(),
    lastScan: json.readOptionalDateTime('lastScan')?.toUtc(),
    connectionTag: json.readOptionalString('connectionTag'),
  );

  final int id;
  final String name;
  final TerminalTypeChoice type;
  final String serialNumber;
  final TerminalStatus status;

  /// The tablet's last check-in since the server started; kept in memory.
  final DateTime? lastSeen;

  /// The last scan registered there, from the audit log.
  final DateTime? lastScan;

  /// Changes each time a tablet connects, so HR sees that this one did. Says
  /// nothing about the secret.
  final String? connectionTag;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.toJson(),
    'serialNumber': serialNumber,
    'status': status.wireName,
    'lastSeen': lastSeen?.toUtc().toIso8601String(),
    'lastScan': lastScan?.toUtc().toIso8601String(),
    'connectionTag': connectionTag,
  };
}

/// `GET /terminals`.
class TerminalListResponse {
  const TerminalListResponse({required this.terminals});

  factory TerminalListResponse.fromJson(Map<String, Object?> json) =>
      TerminalListResponse(terminals: json.readObjectList('terminals').map(Terminal.fromJson).toList());

  final List<Terminal> terminals;

  Map<String, Object?> toJson() => {
    'terminals': [for (final terminal in terminals) terminal.toJson()],
  };
}

/// Body of adding or changing a terminal (Figma `1507:126`, `1507:280`): a
/// van's number plate goes in its name.
class TerminalRequest {
  const TerminalRequest({required this.name, required this.typeId, required this.serialNumber});

  factory TerminalRequest.fromJson(Map<String, Object?> json) => TerminalRequest(
    name: json.readString(fieldName),
    typeId: json.readInt(fieldType),
    serialNumber: json.readString(fieldSerialNumber),
  );

  static const fieldName = 'name';
  static const fieldType = 'typeId';
  static const fieldSerialNumber = 'serialNumber';

  /// Column sizes of `tblDevice` (`deviceName`, `deviceSN`).
  static const maxNameLength = 100;
  static const maxSerialNumberLength = 100;

  final String name;
  final int typeId;
  final String serialNumber;

  TerminalRequest trimmed() => TerminalRequest(name: name.trim(), typeId: typeId, serialNumber: serialNumber.trim());

  Map<String, Object?> toJson() => {fieldName: name, fieldType: typeId, fieldSerialNumber: serialNumber};
}

/// Body of `POST /terminal/pair`: the scanned pairing QR. It is a credential:
/// never logged.
class TerminalPairRequest {
  const TerminalPairRequest({required this.qrCode, required this.deviceId, this.deviceName});

  factory TerminalPairRequest.fromJson(Map<String, Object?> json) => TerminalPairRequest(
    qrCode: json.readString('qrCode'),
    deviceId: json.readString('deviceId'),
    deviceName: json.readOptionalString('deviceName'),
  );

  final String qrCode;

  /// Random, kept by the tablet: only this tablet can retry a pairing.
  final String deviceId;
  final String? deviceName;

  Map<String, Object?> toJson() => {'qrCode': qrCode, 'deviceId': deviceId, 'deviceName': deviceName};

  @override
  String toString() => 'TerminalPairRequest(<redacted>)';
}

/// What a tablet knows about itself. [canScan] is `false` while HR has
/// deactivated it.
class TerminalInfo {
  const TerminalInfo({required this.id, required this.name, required this.canScan});

  factory TerminalInfo.fromJson(Map<String, Object?> json) =>
      TerminalInfo(id: json.readInt('id'), name: json.readString('name'), canScan: json.readBool('canScan'));

  final int id;
  final String name;
  final bool canScan;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'canScan': canScan};
}

/// Response of `POST /terminal/pair`. [token] is the tablet's own credential:
/// stored in its secure storage, never shown or logged.
class TerminalPairResponse {
  const TerminalPairResponse({required this.token, required this.terminal});

  factory TerminalPairResponse.fromJson(Map<String, Object?> json) =>
      TerminalPairResponse(token: json.readString('token'), terminal: TerminalInfo.fromJson(json.readObject('terminal')));

  final String token;
  final TerminalInfo terminal;

  Map<String, Object?> toJson() => {'token': token, 'terminal': terminal.toJson()};

  @override
  String toString() => 'TerminalPairResponse(<redacted>, ${terminal.name})';
}

/// Body of `POST /terminal/scan`. [qrCode] is the employee's Terminal QR, a
/// credential: never logged. [at] is the moment of the scan.
class TerminalScanRequest {
  const TerminalScanRequest({required this.qrCode, required this.at});

  factory TerminalScanRequest.fromJson(Map<String, Object?> json) =>
      TerminalScanRequest(qrCode: json.readString('qrCode'), at: _moment(json, fieldAt));

  static const fieldAt = 'at';

  final String qrCode;
  final DateTime at;

  Map<String, Object?> toJson() => {'qrCode': qrCode, fieldAt: at.toUtc().toIso8601String()};

  @override
  String toString() => 'TerminalScanRequest(<redacted>)';
}

/// What a scan did (D41).
enum TerminalScanOutcome {
  checkedIn('checked_in'),
  checkedOut('checked_out'),

  /// Scanned again within a moment: nothing changed.
  alreadyCheckedIn('already_checked_in'),
  alreadyCheckedOut('already_checked_out');

  const TerminalScanOutcome(this.wireName);

  final String wireName;

  static TerminalScanOutcome fromWire(String value) => values.firstWhere(
    (o) => o.wireName == value,
    orElse: () => throw FormatException('Unknown scan outcome "$value".'),
  );
}

/// Response of `POST /terminal/scan` and `/terminal/switch`.
class TerminalScanResult {
  const TerminalScanResult({
    required this.outcome,
    required this.timeLocal,
    required this.projects,
    this.firstName,
    this.current,
  });

  factory TerminalScanResult.fromJson(Map<String, Object?> json) => TerminalScanResult(
    outcome: TerminalScanOutcome.fromWire(json.readString('outcome')),
    timeLocal: json.readString('timeLocal'),
    firstName: json.readOptionalString('firstName'),
    current: json['current'] == null ? null : CurrentActivity.fromJson(json.readObject('current')),
    projects: json.readObjectList('projects').map(MyProject.fromJson).toList(),
  );

  final TerminalScanOutcome outcome;

  /// Workplace-local `HH:mm` of the registration this answers about.
  final String timeLocal;
  final String? firstName;
  final CurrentActivity? current;

  /// What they can change to: their current projects.
  final List<MyProject> projects;

  Map<String, Object?> toJson() => {
    'outcome': outcome.wireName,
    'timeLocal': timeLocal,
    'firstName': firstName,
    'current': current?.toJson(),
    'projects': [for (final project in projects) project.toJson()],
  };
}

/// Body of `POST /terminal/switch`: "What are you working on?", right after a
/// scan. The Terminal QR proves who it is for, as the scan did.
class TerminalSwitchRequest {
  const TerminalSwitchRequest({required this.qrCode, required this.kind, required this.at, this.projectId});

  factory TerminalSwitchRequest.fromJson(Map<String, Object?> json) => TerminalSwitchRequest(
    qrCode: json.readString('qrCode'),
    kind: ActivityKind.fromWire(json.readString('kind')),
    at: _moment(json, TerminalScanRequest.fieldAt),
    projectId: json.readOptionalInt('projectId'),
  );

  final String qrCode;
  final ActivityKind kind;
  final DateTime at;
  final int? projectId;

  Map<String, Object?> toJson() => {
    'qrCode': qrCode,
    'kind': kind.wireName,
    TerminalScanRequest.fieldAt: at.toUtc().toIso8601String(),
    'projectId': projectId,
  };

  @override
  String toString() => 'TerminalSwitchRequest(<redacted>)';
}

/// A moment, not a wall-clock time: it must say its offset.
DateTime _moment(Map<String, Object?> json, String field) {
  final value = json.readString(field);
  if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw FormatException('"$field" must be a moment with an offset.');
  }
  return DateTime.parse(value).toUtc();
}
