import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../database/sql_executor.dart';
import '../http/api_exception.dart';
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
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TransactionRunner _transactions;
  final RegistrationRounding _rounding;
  final WorkplaceClock _clock;
  final TimeRegistrationWriteRepository _repository;
  final AuditLogRepository _audit;
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
  /// - the same request again (a retry) adds nothing and returns the pair
  ///   stored the first time; [created] is then `false`
  Future<({RegisteredTime registered, bool created})> register(int userId, RegisterTimeRequest request) async {
    final reason = _reasonOf(request);
    final at = DateTime.fromMillisecondsSinceEpoch(request.at.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true);
    if (at.isAfter(_now().toUtc().add(allowedClockSkew))) {
      throw const ApiException.validation(RegisterTimeRequest.fieldAt, 'A registration can’t be in the future.');
    }

    final local = _clock.wallClockOf(at);
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

      final existing = await _repository.findSame(tx, userId, actualType, at);
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

      final actualId = await _repository.insert(
        tx,
        userId: userId,
        typeId: actualType,
        at: at,
        manualEntry: request.entry != RegistrationEntry.now,
        comment: reason,
      );
      // Calculated by Jitan, not entered by hand: not a manual entry.
      final roundedId = await _repository.insert(tx, userId: userId, typeId: roundedType, at: rounded, manualEntry: false);
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
