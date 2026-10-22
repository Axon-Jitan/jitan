import 'package:jitan_models/jitan_models.dart';

import '../time_registration/workplace_clock.dart';
import 'time_record_repository.dart';

/// Turns registrations into Time records days (TIME_ENGINE_ANALYSIS D4, D7,
/// D8, D14, D30, D31): pure, no database or clock of its own.
///
/// Per employee and workplace-local date, for the start and for the finish:
/// - **HR's correction** counts when there is one: the newest active
///   "… – corrected" row, with the rounded row stored right after it.
/// - Otherwise the **registration**: the earliest active actual start / the
///   latest active actual finish, with the rounded row stored after it.
/// - An **employee's correction** (an actual row entered by hand with a
///   reason) does not count until HR approves it, which adds a corrected row
///   after it; until then it is **pending**.
///
/// Status: non-work (every row switched off by "Mark as non-work") ·
/// pending review · corrected / complete · working (today) · missing finish
/// · missing start. A past scheduled working day without any row, from the
/// employee's first registration on, is **no registration**.
abstract final class TimeRecordDays {
  static List<TimeRecordDay> build({
    required List<RegistrationRow> rows,
    required Map<int, EmployeeSummary> employees,
    required WorkplaceClock clock,
    required DateTime today,
    Map<int, Set<int>> scheduledWeekdays = const {},
    Map<int, DateTime> firstRegistrations = const {},
    DateTime? from,
    DateTime? to,
  }) {
    final byUserDay = <int, Map<DateTime, List<RegistrationRow>>>{};
    for (final row in rows) {
      final local = clock.wallClockOf(row.at);
      final date = DateTime.utc(local.year, local.month, local.day);
      byUserDay.putIfAbsent(row.userId, () => {}).putIfAbsent(date, () => []).add(row);
    }

    final days = <TimeRecordDay>[];
    for (final employee in employees.values) {
      final userDays = byUserDay[employee.id] ?? const {};
      for (final MapEntry(key: date, value: dayRows) in userDays.entries) {
        final day = _day(employee, date, dayRows, clock, today);
        if (day != null) days.add(day);
      }
      // Scheduled working days without any registration.
      final weekdays = scheduledWeekdays[employee.id] ?? const {};
      final first = firstRegistrations[employee.id];
      if (weekdays.isEmpty || first == null || from == null || to == null) continue;
      final firstLocal = clock.wallClockOf(first);
      var date = _later(from, DateTime.utc(firstLocal.year, firstLocal.month, firstLocal.day));
      final yesterday = today.subtract(const Duration(days: 1));
      final last = to.isBefore(yesterday) ? to : yesterday;
      while (!date.isAfter(last)) {
        if (weekdays.contains(date.weekday) && !userDays.containsKey(date)) {
          days.add(_empty(employee, date));
        }
        date = DateTime.utc(date.year, date.month, date.day + 1);
      }
    }

    String name(TimeRecordDay d) => '${d.lastName ?? ''} ${d.firstName ?? ''} ${d.employeeCode}'.toLowerCase();
    days.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : name(a).compareTo(name(b));
    });
    return days;
  }

  static TimeRecordDay? _day(EmployeeSummary employee, DateTime date, List<RegistrationRow> rows, WorkplaceClock clock, DateTime today) {
    final byId = [...rows]..sort((a, b) => a.id.compareTo(b.id));
    final kinds = {for (final r in byId) r.id: _kind(r)};
    String local(DateTime utc) => _hhmm(clock.wallClockOf(utc));

    bool isEmployeeCorrection(RegistrationRow r) {
      final kind = kinds[r.id];
      return kind is _Actual && kind.method == TimeRecordMethod.manual && r.manualEntry && (r.comment?.isNotEmpty ?? false);
    }

    final active = [for (final r in byId) if (r.active) r];
    final nonWork = active.isEmpty &&
        byId.any((r) => kinds[r.id] is _Rounded && !r.active && (r.comment?.isNotEmpty ?? false));
    if (active.isEmpty && !nonWork) return null;

    final pending = <TimeRecordPending>[];
    TimeRecordTime? side(RegistrationBoundary boundary) {
      bool of<T extends _Kind>(RegistrationRow r) => kinds[r.id] is T && kinds[r.id]!.boundary == boundary;
      final corrections = [for (final r in active) if (of<_Corrected>(r)) r];
      final requests = [for (final r in active) if (of<_Actual>(r) && isEmployeeCorrection(r)) r];
      for (final request in requests) {
        if (!corrections.any((c) => c.id > request.id)) {
          pending.add(
            TimeRecordPending(
              id: request.id,
              boundary: boundary,
              requested: request.at,
              requestedLocal: local(request.at),
              reason: request.comment,
            ),
          );
        }
      }
      final detected = [for (final r in active) if (of<_Actual>(r) && !isEmployeeCorrection(r)) r]
        ..sort((a, b) => a.at.compareTo(b.at));
      final registration = detected.isEmpty
          ? null
          : (boundary == RegistrationBoundary.start ? detected.first : detected.last);
      RegistrationRow? roundedAfter(RegistrationRow row) =>
          active.where((r) => of<_Rounded>(r) && r.id > row.id).firstOrNull;

      if (corrections.isNotEmpty) {
        final correction = corrections.last;
        final rounded = roundedAfter(correction);
        return TimeRecordTime(
          actualId: correction.id,
          actual: correction.at,
          rounded: rounded?.at,
          method: registration == null ? TimeRecordMethod.manual : (kinds[registration.id]! as _Actual).method,
          enteredByHand: true,
          actualLocal: local(correction.at),
          roundedLocal: rounded == null ? null : local(rounded.at),
          reason: correction.comment,
          correctedBy: TimeCorrectionBy.hr,
          originalLocal: registration == null ? null : local(registration.at),
        );
      }
      if (registration == null) return null;
      final rounded = roundedAfter(registration);
      return TimeRecordTime(
        actualId: registration.id,
        actual: registration.at,
        rounded: rounded?.at,
        method: (kinds[registration.id]! as _Actual).method,
        enteredByHand: registration.manualEntry,
        actualLocal: local(registration.at),
        roundedLocal: rounded == null ? null : local(rounded.at),
        reason: registration.comment,
      );
    }

    final start = nonWork ? null : side(RegistrationBoundary.start);
    final finish = nonWork ? null : side(RegistrationBoundary.finish);
    final status = switch ((start, finish)) {
      _ when nonWork => TimeRecordStatus.nonWork,
      _ when pending.isNotEmpty => TimeRecordStatus.pendingReview,
      (final s?, final f?) when s.correctedBy != null || f.correctedBy != null => TimeRecordStatus.corrected,
      (_?, _?) => TimeRecordStatus.complete,
      (_?, null) => date == today ? TimeRecordStatus.working : TimeRecordStatus.missingFinish,
      (null, _?) => TimeRecordStatus.missingStart,
      _ => null,
    };
    if (status == null) return null;

    final events = <TimeRecordEvent>[
      for (final r in [...byId]..sort((a, b) => a.at.compareTo(b.at) != 0 ? a.at.compareTo(b.at) : a.id.compareTo(b.id)))
        if (kinds[r.id] case final _Actual actual)
          TimeRecordEvent(
            atLocal: local(r.at),
            boundary: actual.boundary,
            kind: switch (r.active) {
              _ when nonWork => TimeRecordEventKind.nonWork,
              true when isEmployeeCorrection(r) => TimeRecordEventKind.correctionRequested,
              false when isEmployeeCorrection(r) => TimeRecordEventKind.rejected,
              _ => TimeRecordEventKind.registered,
            },
            active: r.active,
            method: actual.method,
            reason: r.comment,
          )
        else if (kinds[r.id] case final _Corrected corrected)
          TimeRecordEvent(
            atLocal: local(r.at),
            boundary: corrected.boundary,
            kind: nonWork ? TimeRecordEventKind.nonWork : TimeRecordEventKind.corrected,
            active: r.active,
            reason: r.comment,
          ),
    ];

    return TimeRecordDay(
      employeeId: employee.id,
      firstName: employee.firstName,
      lastName: employee.lastName,
      employeeCode: employee.code,
      date: date,
      status: status,
      start: start,
      finish: finish,
      pending: pending,
      events: events,
      nonWorkReason: nonWork
          ? byId.where((r) => kinds[r.id] is _Rounded && (r.comment?.isNotEmpty ?? false)).firstOrNull?.comment
          : null,
      companyIds: employee.companyIds,
    );
  }

  static TimeRecordDay _empty(EmployeeSummary employee, DateTime date) => TimeRecordDay(
    employeeId: employee.id,
    firstName: employee.firstName,
    lastName: employee.lastName,
    employeeCode: employee.code,
    date: date,
    status: TimeRecordStatus.noRegistration,
    companyIds: employee.companyIds,
  );

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  static String _hhmm(DateTime wallClock) =>
      '${wallClock.hour.toString().padLeft(2, '0')}:${wallClock.minute.toString().padLeft(2, '0')}';

  static final _actualType = RegExp(r'^(Start|Finish) – actual – (Geofence|QR|Manual)$');
  static final _otherType = RegExp(r'^(Start|Finish) – (rounded|corrected)$');

  static _Kind? _kind(RegistrationRow row) {
    if (_actualType.firstMatch(row.typeName) case final m?) {
      return _Actual(
        _boundary(m.group(1)!),
        switch (m.group(2)) {
          'Geofence' => TimeRecordMethod.geofence,
          'QR' => TimeRecordMethod.qr,
          _ => TimeRecordMethod.manual,
        },
      );
    }
    if (_otherType.firstMatch(row.typeName) case final m?) {
      return m.group(2) == 'rounded' ? _Rounded(_boundary(m.group(1)!)) : _Corrected(_boundary(m.group(1)!));
    }
    return null;
  }

  static RegistrationBoundary _boundary(String word) =>
      word == 'Start' ? RegistrationBoundary.start : RegistrationBoundary.finish;
}

sealed class _Kind {
  const _Kind(this.boundary);

  final RegistrationBoundary boundary;
}

/// "Start – actual – QR" …: as registered.
class _Actual extends _Kind {
  const _Actual(super.boundary, this.method);

  final TimeRecordMethod method;
}

/// "Start – rounded": the time that counts for its actual or corrected row.
class _Rounded extends _Kind {
  const _Rounded(super.boundary);
}

/// "Start – corrected": HR's correction or an approved employee correction.
class _Corrected extends _Kind {
  const _Corrected(super.boundary);
}
