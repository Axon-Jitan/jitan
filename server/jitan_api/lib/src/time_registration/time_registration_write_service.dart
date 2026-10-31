import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
import '../locations/location_repository.dart';
import 'registration_rounding.dart';
import 'rounding/rounding_calculator.dart';
import 'rounding/rounding_policy.dart';
import 'time_reg_type_names.dart';
import 'time_registration_write_repository.dart';
import 'workplace_clock.dart';

/// Registers an employee's start or finish (phase 3, TIME_ENGINE_ANALYSIS
/// D4–D9): two `tblTimeReg` rows in one audited transaction, the **actual**
/// time (type "Start – actual – Manual", …; never changed) and the time
/// **rounded** with the employee's schedule for that weekday ("Start –
/// rounded"), both UTC. Rounding is done in the workplace's local time.
///
/// Every start and finish is rounded with the day's rule. Rounding only the
/// day's first start and last finish (D22) matters once activities can be
/// switched, which comes with IT's projects update (D16, D19).
class TimeRegistrationWriteService {
  TimeRegistrationWriteService({
    required this._transactions,
    required this._rounding,
    required this._clock,
    this._repository = const TimeRegistrationWriteRepository(),
    this._audit = const AuditLogRepository(),
    this._locations = const LocationRepository(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TransactionRunner _transactions;
  final RegistrationRounding _rounding;
  final WorkplaceClock _clock;
  final TimeRegistrationWriteRepository _repository;
  final AuditLogRepository _audit;
  final LocationRepository _locations;
  final DateTime Function() _now;

  /// How far ahead of the server's clock a time may be (a phone's clock may
  /// run a little fast); anything later is refused.
  static const allowedClockSkew = Duration(minutes: 2);

  /// Registers [request] for [userId] and returns the stored pair.
  ///
  /// D30: a time tapped when it happened needs no reason and is not a manual
  /// entry; a corrected time needs a reason and is one; the first-day time
  /// needs no reason, is a manual entry and is allowed only while the
  /// employee has no registration yet.
  ///
  /// - 400 `validation_failed` on `reason` (missing for a corrected time, or
  ///   longer than [RegisterTimeRequest.maxReasonLength]), on `at` (in the
  ///   future) or on `entry` (a first-day time once there are registrations)
  /// - 400 on `entry` or `addressId` for a geofence registration that is not
  ///   sent as it happened, or names no active location
  /// - the same request again (a retry) adds nothing and returns the pair
  ///   stored the first time; [created] is then `false`
  /// - a geofence start while the day is already running (back from a short
  ///   exit, or at another location: D32) adds nothing and returns that start
  Future<({RegisteredTime registered, bool created})> register(int userId, RegisterTimeRequest request) async {
    final reason = _reasonOf(request);
    final at = DateTime.fromMillisecondsSinceEpoch(request.at.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);
    if (at.isAfter(_now().toUtc().add(allowedClockSkew))) {
      throw const ApiException.validation(RegisterTimeRequest.fieldAt, 'A registration can’t be in the future.');
    }

    final local = _clock.wallClockOf(at);
    final geofence = request.method == TimeRegistrationMethod.geofence;
    if (geofence && request.entry != RegistrationEntry.now) {
      throw const ApiException.validation(RegisterTimeRequest.fieldEntry, 'A detected time is sent as it happened.');
    }
    final policy = await _rounding.policyOn(userId, local.weekday);
    final boundary = switch (request.boundary) {
      RegistrationBoundary.start => RoundingBoundary.start,
      RegistrationBoundary.finish => RoundingBoundary.finish,
    };
    final rounded = _clock.utcOf(RoundingCalculator.round(actual: local, boundary: boundary, policy: policy).registered);

    return _transactions.transaction((tx) async {
      final actualType = await _type(tx, TimeRegTypeNames.actual(request.boundary, request.method));
      final roundedType = await _type(tx, TimeRegTypeNames.rounded(request.boundary));
      await _repository.lockUser(tx, userId);
      final addressId = geofence ? await _locationOf(tx, request) : null;

      final existing = await _repository.findSame(tx, userId, actualType, at);
      final pending = request.entry == RegistrationEntry.corrected;
      if (existing != null && pending) {
        return (
          registered: RegisteredTime(boundary: request.boundary, actualId: existing, actualAt: at),
          created: false,
        );
      }
      if (existing == null && request.entry == RegistrationEntry.firstDay && await _repository.hasAny(tx, userId)) {
        throw const ApiException.validation(
          RegisterTimeRequest.fieldEntry,
          'The arrival time of the first day can only be set before anything else is registered.',
        );
      }
      if (existing != null) {
        final pair = await _repository.nextOfType(tx, userId, roundedType, existing);
        if (pair != null) {
          return (
            registered: RegisteredTime(
              boundary: request.boundary,
              actualId: existing,
              actualAt: at,
              roundedId: pair.id,
              roundedAt: pair.at,
            ),
            created: false,
          );
        }
      }

      if (existing == null && geofence && request.boundary == RegistrationBoundary.start) {
        final running = await _runningStart(tx, userId, at, local);
        if (running != null) {
          return (
            registered: RegisteredTime(boundary: request.boundary, actualId: running.id, actualAt: running.at),
            created: false,
          );
        }
      }

      final actualId = await _repository.insert(
        tx,
        userId: userId,
        typeId: actualType,
        at: at,
        manualEntry: request.entry != RegistrationEntry.now,
        comment: reason,
        addressId: addressId,
      );
      // D31: a correction waits for HR; it gets its rounded row when approved.
      if (pending) {
        await _audit.record(
          tx,
          AuditEvent(
            type: AuditEventType.timeCorrectionRequested,
            actorUserId: userId,
            references: {
              EventLogReference.user: userId,
              EventLogReference.timeReg: actualId,
              EventLogReference.timeRegType: actualType,
            },
          ),
        );
        return (
          registered: RegisteredTime(boundary: request.boundary, actualId: actualId, actualAt: at),
          created: true,
        );
      }
      // Calculated by Jitan, not entered by hand: not a manual entry.
      final roundedId = await _repository.insert(
        tx,
        userId: userId,
        typeId: roundedType,
        at: rounded,
        manualEntry: false,
        addressId: addressId,
      );
      await _audit.record(
        tx,
        AuditEvent(
          type: AuditEventType.timeRegistered,
          actorUserId: userId,
          references: {
            EventLogReference.user: userId,
            EventLogReference.timeReg: actualId,
            EventLogReference.timeRegType: actualType,
          },
        ),
      );
      return (
        registered: RegisteredTime(
          boundary: request.boundary,
          actualId: actualId,
          actualAt: at,
          roundedId: roundedId,
          roundedAt: rounded,
        ),
        created: true,
      );
    });
  }

  /// The active location of a geofence registration; 400 otherwise.
  Future<int> _locationOf(SqlExecutor tx, RegisterTimeRequest request) async {
    final id = request.addressId;
    final location = id == null ? null : await _locations.find(tx, id);
    if (location == null || !location.isActive) {
      throw const ApiException.validation(RegisterTimeRequest.fieldAddressId, 'This location is not recognised.');
    }
    return location.id;
  }

  /// The latest start of the workplace day of [at] when no finish follows it.
  Future<({int id, DateTime at})?> _runningStart(SqlExecutor tx, int userId, DateTime at, DateTime local) async {
    Future<List<int>> ids(RegistrationBoundary boundary) async => [
      for (final method in TimeRegistrationMethod.values)
        ?await _repository.typeId(tx, TimeRegTypeNames.actual(boundary, method)),
    ];
    final starts = await ids(RegistrationBoundary.start);
    final finishes = await ids(RegistrationBoundary.finish);
    final midnight = _clock.utcOf(DateTime(local.year, local.month, local.day));
    final latest = await _repository.latestOfTypes(tx, userId, [...starts, ...finishes], midnight, at);
    return latest == null || finishes.contains(latest.typeId) ? null : (id: latest.id, at: latest.at);
  }

  /// The reason, trimmed: required for a corrected time (D30).
  static String? _reasonOf(RegisterTimeRequest request) {
    final reason = request.reason?.trim() ?? '';
    if (request.entry == RegistrationEntry.corrected && reason.isEmpty) {
      throw const ApiException.validation(RegisterTimeRequest.fieldReason, 'Say why you correct this time.');
    }
    if (reason.runes.length > RegisterTimeRequest.maxReasonLength) {
      throw const ApiException.validation(
        RegisterTimeRequest.fieldReason,
        'The reason must be at most ${RegisterTimeRequest.maxReasonLength} characters.',
      );
    }
    return reason.isEmpty ? null : reason;
  }

  Future<int> _type(SqlExecutor tx, String name) async =>
      await _repository.typeId(tx, name) ??
      (throw ApiException.configurationError('tblTimeRegType has no active row named "$name".'));
}
