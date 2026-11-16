import 'package:jitan_models/jitan_models.dart';

import '../audit/audit_event.dart';
import '../audit/audit_log_repository.dart';
import '../companies/company_repository.dart';
import '../database/sql_executor.dart';
import '../employees/employee_repository.dart';
import '../http/api_exception.dart';
import '../time_registration/registration_rounding.dart';
import '../time_registration/rounding/rounding_calculator.dart';
import '../time_registration/rounding/rounding_policy.dart';
import '../time_registration/time_reg_type_names.dart';
import '../time_registration/time_registration_write_repository.dart';
import '../time_registration/workplace_clock.dart';
import 'time_correction_repository.dart';
import 'time_record_repository.dart';
import 'time_record_service.dart';

/// HR/Admin corrections in Time records (phase 3, slice 3; Figma `160:220`,
/// `160:338`, `272:457`, `273:166`; TIME_ENGINE_ANALYSIS D7, D8, D31). Each
/// change is one audited transaction under the employee's row lock, and
/// nothing is deleted: a replaced row is switched off and stays as history.
class TimeCorrectionService {
  TimeCorrectionService({
    required this._transactions,
    required this._employees,
    required this._companies,
    required this._records,
    required this._days,
    required this._rounding,
    required this._clock,
    this._writes = const TimeRegistrationWriteRepository(),
    this._switches = const TimeCorrectionRepository(),
    this._audit = const AuditLogRepository(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TransactionRunner _transactions;
  final EmployeeRepository _employees;
  final CompanyRepository _companies;
  final TimeRecordRepository _records;
  final TimeRecordService _days;
  final RegistrationRounding _rounding;
  final WorkplaceClock _clock;
  final TimeRegistrationWriteRepository _writes;
  final TimeCorrectionRepository _switches;
  final AuditLogRepository _audit;
  final DateTime Function() _now;

  static const maxReasonLength = 500;

  /// HR corrects (or adds) the start or finish of [date] (D7, D8): a
  /// "… – corrected" row with the reason and its rounded row; the start or
  /// finish that counted until now (corrected and rounded rows) is switched
  /// off.
  ///
  /// 400 for a missing reason, a time in the future or on another day.
  Future<TimeRecordDay?> correct(int actorUserId, int companyId, int userId, String date, CorrectTimeRequest request) async {
    final day = _parseDate(date);
    final reason = _reason(request.reason);
    final at = _atOf(day, request.time);
    if (at.isAfter(_now().toUtc().add(const Duration(minutes: 2)))) {
      throw const ApiException.validation(CorrectTimeRequest.fieldTime, 'A time can’t be in the future.');
    }
    final employee = await _member(companyId, userId);
    // Read before the transaction: inside it, a second connection could be
    // waited for while holding the first (review M10).
    final policy = await _rounding.policyOn(userId, day.weekday);
    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final correctedId = await _count(tx, userId, day, request.boundary, at, reason, policy);
      await _record(tx, AuditEventType.timeCorrected, actorUserId, userId, companyId, correctedId);
    });
    return _dayOf(employee, day);
  }

  /// What [time] (`HH:mm`) on [date] would count as after rounding with
  /// [userId]'s schedule (Figma `272:457` "Calculated from the applicable
  /// rounding rule"); nothing is stored.
  Future<String> preview(int companyId, int userId, String date, RegistrationBoundary boundary, String time) async {
    final day = _parseDate(date);
    final String checked;
    try {
      checked = CorrectTimeRequest.localTime(time);
    } on FormatException catch (e) {
      throw ApiException.validation(CorrectTimeRequest.fieldTime, e.message);
    }
    await _member(companyId, userId);
    final policy = await _rounding.policyOn(userId, day.weekday);
    final rounded = RoundingCalculator.round(
      actual: _clock.wallClockOf(_atOf(day, checked)),
      boundary: boundary == RegistrationBoundary.start ? RoundingBoundary.start : RoundingBoundary.finish,
      policy: policy,
    ).registered;
    return '${rounded.hour.toString().padLeft(2, '0')}:${rounded.minute.toString().padLeft(2, '0')}';
  }

  /// HR approves the employee's correction [registrationId] (D31): it becomes
  /// HR's corrected time and counts; the employee's row stays as history.
  Future<TimeRecordDay?> approve(int actorUserId, int companyId, int userId, int registrationId) async {
    final employee = await _member(companyId, userId);
    // The request's day and rounding rule before the transaction (review M10);
    // a request's time never changes, and it is checked again inside.
    final request = await _transactions.transaction((tx) => _records.registrationOf(tx, userId, registrationId));
    final day = request == null ? null : _localDate(request.at);
    final policy = day == null ? null : await _rounding.policyOn(userId, day.weekday);
    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final (:row, :boundary) = await _pendingRequest(tx, userId, registrationId);
      final correctedId = await _count(tx, userId, day!, boundary, row.at, row.comment, policy!);
      await _record(tx, AuditEventType.timeCorrectionApproved, actorUserId, userId, companyId, correctedId);
    });
    return _dayOf(employee, day!);
  }

  /// HR rejects the employee's correction [registrationId] (D31): it is
  /// switched off and the day is as before.
  Future<TimeRecordDay?> reject(int actorUserId, int companyId, int userId, int registrationId) async {
    final employee = await _member(companyId, userId);
    late DateTime day;
    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final (:row, boundary: _) = await _pendingRequest(tx, userId, registrationId);
      day = _localDate(row.at);
      await _switches.switchOff(tx, [row.id], _now().toUtc());
      await _record(tx, AuditEventType.timeCorrectionRejected, actorUserId, userId, companyId, row.id);
    });
    return _dayOf(employee, day);
  }

  /// HR marks [date] as non-work (Figma `273:166`): the day's registrations
  /// are switched off, the reason kept on its rounded rows. 409 when the day
  /// has nothing to switch off (an absence can't be stored yet, GAP-16) or
  /// only a correction waiting for review.
  Future<TimeRecordDay?> markNonWork(int actorUserId, int companyId, int userId, String date, String reasonText) async {
    final day = _parseDate(date);
    final reason = _reason(reasonText);
    final employee = await _member(companyId, userId);
    await _transactions.transaction((tx) async {
      await _writes.lockUser(tx, userId);
      final active = [for (final r in await _dayRows(tx, userId, day)) if (r.active) r];
      final rounded = [for (final r in active) if (r.typeName.endsWith('– rounded')) r.id];
      if (rounded.isEmpty) {
        throw const ApiException(
          409,
          ApiErrorCode.nothingToMarkNonWork,
          'This day has no counted time to mark as non-work. Approve or reject a pending correction first.',
        );
      }
      final now = _now().toUtc();
      await _switches.switchOff(tx, rounded, now, comment: reason);
      await _switches.switchOff(tx, [for (final r in active) if (!rounded.contains(r.id)) r.id], now);
      await _record(tx, AuditEventType.timeMarkedNonWork, actorUserId, userId, companyId, rounded.first);
    });
    return _dayOf(employee, day);
  }

  /// Makes [at] the [boundary] of [day] that counts (D7, D8, D34b): switches
  /// off only what it replaces, then adds a corrected row with [reason] and its
  /// rounded row (rounded like any time).
  ///
  /// - A start replaces the start that counts (HR's newest corrected start, or
  ///   the day's first detected start) and that start's rounded row.
  /// - A finish after the day's latest start replaces the finish that counts
  ///   the same way. A finish at or before the latest start closes the gap
  ///   between leaving and coming back (travelling, D34b) and replaces nothing,
  ///   so the day keeps its end (review H3, 2026-11-16).
  /// - 400 for a finish before the day's first start, or a start after the
  ///   day's finish.
  ///
  /// Returns the corrected row's id.
  Future<int> _count(
    SqlExecutor tx,
    int userId,
    DateTime day,
    RegistrationBoundary boundary,
    DateTime at,
    String? reason,
    RoundingPolicy policy,
  ) async {
    final active = [for (final r in await _dayRows(tx, userId, day)) if (r.active) r]..sort((a, b) => a.id.compareTo(b.id));
    bool isRequest(RegistrationRow r) =>
        _requestType.hasMatch(r.typeName) && r.manualEntry && (r.comment?.isNotEmpty ?? false);
    bool counts(RegistrationRow r, RegistrationBoundary b) =>
        r.typeName == TimeRegTypeNames.corrected(b) || (r.typeName.startsWith('${_name(b)} – actual') && !isRequest(r));
    final starts = [for (final r in active) if (counts(r, RegistrationBoundary.start)) r.at]..sort();
    final finishes = [for (final r in active) if (counts(r, RegistrationBoundary.finish)) r.at]..sort();
    final latestStart = starts.lastOrNull;

    if (boundary == RegistrationBoundary.finish && starts.isNotEmpty && !at.isAfter(starts.first)) {
      throw const ApiException.validation(CorrectTimeRequest.fieldTime, 'A finish can’t be before the start.');
    }
    final dayFinish = finishes.lastOrNull;
    final dayEnded = dayFinish != null && (latestStart == null || !dayFinish.isBefore(latestStart));
    if (boundary == RegistrationBoundary.start && dayEnded && !at.isBefore(dayFinish)) {
      throw const ApiException.validation(CorrectTimeRequest.fieldTime, 'A start can’t be after the finish.');
    }

    final closesGap = boundary == RegistrationBoundary.finish && latestStart != null && !at.isAfter(latestStart);
    final replaced = <int>[];
    if (!closesGap) {
      // HR's corrections of this start, or of the day's end (a gap's stay).
      final corrections = [
        for (final r in active)
          if (r.typeName == TimeRegTypeNames.corrected(boundary) &&
              (boundary == RegistrationBoundary.start || latestStart == null || r.at.isAfter(latestStart)))
            r,
      ];
      final detected = [
        for (final r in active)
          if (counts(r, boundary) && r.typeName != TimeRegTypeNames.corrected(boundary)) r,
      ]..sort((a, b) => a.at.compareTo(b.at));
      final counting = corrections.isNotEmpty
          ? corrections.last
          : detected.isEmpty
          ? null
          : (boundary == RegistrationBoundary.start ? detected.first : detected.last);
      replaced.addAll([for (final r in corrections) r.id]);
      if (counting != null) {
        final paired = active.where((r) => r.typeName == TimeRegTypeNames.rounded(boundary) && r.id > counting.id).firstOrNull;
        if (paired != null) replaced.add(paired.id);
      }
    }
    await _switches.switchOff(tx, replaced, _now().toUtc());
    final rounded = _clock.utcOf(
      RoundingCalculator.round(
        actual: _clock.wallClockOf(at),
        boundary: boundary == RegistrationBoundary.start ? RoundingBoundary.start : RoundingBoundary.finish,
        policy: policy,
      ).registered,
    );
    final correctedId = await _writes.insert(
      tx,
      userId: userId,
      typeId: await _type(tx, TimeRegTypeNames.corrected(boundary)),
      at: at,
      manualEntry: true,
      comment: reason,
    );
    await _writes.insert(tx, userId: userId, typeId: await _type(tx, TimeRegTypeNames.rounded(boundary)), at: rounded, manualEntry: false);
    return correctedId;
  }

  static final _requestType = RegExp(r'^(Start|Finish) – actual – Manual$');

  static String _name(RegistrationBoundary b) => b == RegistrationBoundary.start ? 'Start' : 'Finish';

  /// The employee's correction [id] of [userId] that still waits for HR, or
  /// 404 (unknown, another employee's, switched off, not a correction, or
  /// already approved).
  Future<({RegistrationRow row, RegistrationBoundary boundary})> _pendingRequest(SqlExecutor tx, int userId, int id) async {
    final row = await _records.registrationOf(tx, userId, id);
    final match = row == null ? null : RegExp(r'^(Start|Finish) – actual – Manual$').firstMatch(row.typeName);
    if (row == null || match == null || !row.active || !row.manualEntry || (row.comment?.isEmpty ?? true)) {
      throw ApiException.notFound('No correction $id waiting for review.');
    }
    final boundary = match.group(1) == 'Start' ? RegistrationBoundary.start : RegistrationBoundary.finish;
    // Approved = HR's corrected row at the request's own time, stored after it.
    // Another correction of the day leaves the request waiting (review L1).
    final approved = (await _dayRows(tx, userId, _localDate(row.at))).any(
      (r) => r.active && r.id > row.id && r.typeName == TimeRegTypeNames.corrected(boundary) && r.at == row.at,
    );
    if (approved) throw ApiException.notFound('No correction $id waiting for review.');
    return (row: row, boundary: boundary);
  }

  Future<List<RegistrationRow>> _dayRows(SqlExecutor tx, int userId, DateTime day) =>
      _records.registrationsOf([userId], _clock.utcOf(day), _clock.utcOf(day.add(const Duration(days: 1))), executor: tx);

  Future<EmployeeSummary> _member(int companyId, int userId) async {
    if (!await _companies.exists(companyId)) throw ApiException.notFound('Company $companyId does not exist.');
    final employee = await _transactions.transaction<EmployeeSummary?>((tx) => _employees.findInCompany(tx, companyId, userId));
    return employee ?? (throw ApiException.notFound('Employee $userId is not in company $companyId.'));
  }

  Future<TimeRecordDay?> _dayOf(EmployeeSummary employee, DateTime day) async =>
      (await _days.daysOf([employee], day, day)).firstOrNull;

  Future<void> _record(SqlExecutor tx, AuditEventType type, int actor, int userId, int companyId, int timeRegId) => _audit.record(
    tx,
    AuditEvent(
      type: type,
      actorUserId: actor,
      references: {EventLogReference.user: userId, EventLogReference.company: companyId, EventLogReference.timeReg: timeRegId},
    ),
  );

  Future<int> _type(SqlExecutor tx, String name) async =>
      await _writes.typeId(tx, name) ??
      (throw ApiException.configurationError('tblTimeRegType has no active row named "$name".'));

  DateTime _localDate(DateTime utc) {
    final local = _clock.wallClockOf(utc);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// The UTC moment of local [time] (`HH:mm`) on [day].
  DateTime _atOf(DateTime day, String time) {
    final [hour, minute] = time.split(':').map(int.parse).toList();
    return _clock.utcOf(DateTime.utc(day.year, day.month, day.day, hour, minute));
  }

  static String _reason(String text) {
    final reason = text.trim();
    if (reason.isEmpty) throw const ApiException.validation('reason', 'Give the reason for this correction.');
    if (reason.runes.length > maxReasonLength) {
      throw const ApiException.validation('reason', 'The reason must be at most $maxReasonLength characters.');
    }
    return reason;
  }

  static DateTime _parseDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) throw const ApiException.notFound('No such day.');
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
