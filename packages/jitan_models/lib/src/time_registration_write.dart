import 'json_reading.dart';

/// Whether a registration starts or finishes work.
enum RegistrationBoundary {
  start('start'),
  finish('finish');

  const RegistrationBoundary(this.wireName);

  final String wireName;

  static RegistrationBoundary fromWire(String value) => values.firstWhere(
        (b) => b.wireName == value,
        orElse: () => throw FormatException('Unknown boundary "$value".'),
      );
}

/// How a registration was made (TIME_ENGINE_ANALYSIS D5): part of the
/// "actual" `tblTimeRegType`. Only manual registration is accepted from the
/// employee app today; QR (terminals, GAP-09) and geofence (phase 4) come
/// later through the same request.
enum TimeRegistrationMethod {
  manual('manual');

  const TimeRegistrationMethod(this.wireName);

  final String wireName;

  static TimeRegistrationMethod fromWire(String value) => values.firstWhere(
        (m) => m.wireName == value,
        orElse: () => throw FormatException('Unknown registration method "$value".'),
      );
}

/// How a manual registration came in (TIME_ENGINE_ANALYSIS D30).
enum RegistrationEntry {
  /// Tapped when it happened ("Start work" at 08:00): no reason, not a time
  /// entered by hand.
  now('now'),

  /// Entered afterwards because the employee forgot (at 10:00: "started
  /// 08:00"): a reason is required.
  corrected('corrected'),

  /// "When did you arrive?" right after onboarding: no reason, only while the
  /// employee has no registration yet.
  firstDay('first_day');

  const RegistrationEntry(this.wireName);

  final String wireName;

  static RegistrationEntry fromWire(String value) => values.firstWhere(
        (e) => e.wireName == value,
        orElse: () => throw FormatException('Unknown entry "$value".'),
      );
}

/// Body of `POST /me/time-registrations`: the employee's own start or
/// finish.
class RegisterTimeRequest {
  const RegisterTimeRequest({
    required this.boundary,
    required this.method,
    required this.entry,
    required this.at,
    this.reason,
  });

  factory RegisterTimeRequest.fromJson(Map<String, Object?> json) {
    final at = json.readString(fieldAt);
    // A moment, not a wall-clock time: it must say its offset (Z or ±hh:mm).
    if (!RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(at)) {
      throw const FormatException('"at" must be a moment with an offset, e.g. 2026-10-22T06:01:00Z.');
    }
    return RegisterTimeRequest(
      boundary: RegistrationBoundary.fromWire(json.readString(fieldBoundary)),
      method: TimeRegistrationMethod.fromWire(json.readString(fieldMethod)),
      entry: RegistrationEntry.fromWire(json.readString(fieldEntry)),
      at: DateTime.parse(at).toUtc(),
      reason: json.readOptionalString(fieldReason),
    );
  }

  final RegistrationBoundary boundary;
  final TimeRegistrationMethod method;
  final RegistrationEntry entry;

  /// When it happened (UTC): for a manual registration the time the employee
  /// entered; queued offline registrations keep the moment they happened.
  final DateTime at;

  /// Required for a [RegistrationEntry.corrected] time (D30), at most
  /// [maxReasonLength] characters (`tblTimeReg.timeRegComment`).
  final String? reason;

  static const maxReasonLength = 500;

  static const fieldBoundary = 'boundary';
  static const fieldMethod = 'method';
  static const fieldEntry = 'entry';
  static const fieldAt = 'at';
  static const fieldReason = 'reason';

  Map<String, Object?> toJson() => {
        fieldBoundary: boundary.wireName,
        fieldMethod: method.wireName,
        fieldEntry: entry.wireName,
        fieldAt: at.toUtc().toIso8601String(),
        fieldReason: reason,
      };
}

/// Response of `POST /me/time-registrations`: the two rows stored (D4), the
/// actual time (never changed) and the time rounded with the employee's
/// schedule, both UTC.
class RegisteredTime {
  const RegisteredTime({
    required this.boundary,
    required this.actualId,
    required this.actualAt,
    required this.roundedId,
    required this.roundedAt,
  });

  factory RegisteredTime.fromJson(Map<String, Object?> json) => RegisteredTime(
        boundary: RegistrationBoundary.fromWire(json.readString('boundary')),
        actualId: json.readInt('actualId'),
        actualAt: DateTime.parse(json.readString('actualAt')).toUtc(),
        roundedId: json.readInt('roundedId'),
        roundedAt: DateTime.parse(json.readString('roundedAt')).toUtc(),
      );

  final RegistrationBoundary boundary;
  final int actualId;
  final DateTime actualAt;
  final int roundedId;
  final DateTime roundedAt;

  Map<String, Object?> toJson() => {
        'boundary': boundary.wireName,
        'actualId': actualId,
        'actualAt': actualAt.toUtc().toIso8601String(),
        'roundedId': roundedId,
        'roundedAt': roundedAt.toUtc().toIso8601String(),
      };
}
