import 'json_reading.dart';

/// One `tblTimeReg` row as stored: an observed or manually entered
/// registration event. Read-only for now: nothing is rounded, corrected or
/// interpreted here.
///
/// - [timestamp] is the stored `timeRegTimestamp`, a wall-clock value without
///   timezone (GAP-02). JSON carries it without offset; clients show it as
///   is and never convert it.
/// - [typeId] / [typeName] are `tblTimeRegType` as configured. What a type
///   means (in/out, method, …) is open (CLARIFY-02), so no meaning is
///   attached.
/// - [isManualEntry] is `timeRegManualEntry`; `null` when not recorded.
class TimeRegistration {
  const TimeRegistration({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.typeId,
    required this.typeName,
    required this.addressId,
    required this.addressName,
    required this.isManualEntry,
    required this.comment,
    required this.modifiedAt,
  });

  factory TimeRegistration.fromJson(Map<String, Object?> json) => TimeRegistration(
        id: json.readInt('id'),
        userId: json.readInt('userId'),
        timestamp: json.readOptionalDateTime('timestamp') ?? (throw const FormatException('Expected "timestamp".')),
        typeId: json.readOptionalInt('typeId'),
        typeName: json.readOptionalString('typeName'),
        addressId: json.readOptionalInt('addressId'),
        addressName: json.readOptionalString('addressName'),
        isManualEntry: json.readOptionalBool('isManualEntry'),
        comment: json.readOptionalString('comment'),
        modifiedAt: json.readOptionalDateTime('modifiedAt'),
      );

  final int id;
  final int userId;
  final DateTime timestamp;
  final int? typeId;
  final String? typeName;
  final int? addressId;

  /// `tblAddress.addressLogicalName`, e.g. "Almeco office".
  final String? addressName;
  final bool? isManualEntry;
  final String? comment;

  /// `timeRegWhenModified`, wall-clock like [timestamp].
  final DateTime? modifiedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'userId': userId,
        'timestamp': timestamp.toIso8601String(),
        'typeId': typeId,
        'typeName': typeName,
        'addressId': addressId,
        'addressName': addressName,
        'isManualEntry': isManualEntry,
        'comment': comment,
        'modifiedAt': modifiedAt?.toIso8601String(),
      };
}

/// One page of registrations, oldest first (timestamp, then id).
/// [nextCursor] fetches the following page; `null` on the last one.
class TimeRegistrationPage {
  const TimeRegistrationPage({required this.registrations, required this.nextCursor});

  factory TimeRegistrationPage.fromJson(Map<String, Object?> json) => TimeRegistrationPage(
        registrations: [for (final r in json.readObjectList('registrations')) TimeRegistration.fromJson(r)],
        nextCursor: json.readOptionalString('nextCursor'),
      );

  final List<TimeRegistration> registrations;
  final String? nextCursor;

  Map<String, Object?> toJson() => {
        'registrations': [for (final r in registrations) r.toJson()],
        'nextCursor': nextCursor,
      };
}

/// Query parameters of the time-registration list endpoints.
abstract final class TimeRegistrationQuery {
  /// Inclusive start, wall-clock `yyyy-MM-dd` or `yyyy-MM-ddTHH:mm[:ss]`
  /// without offset (GAP-02). Required.
  static const from = 'from';

  /// Exclusive end, same format. Required.
  static const to = 'to';

  /// Page size.
  static const limit = 'limit';

  /// `nextCursor` of the previous page.
  static const cursor = 'cursor';
}
