import 'package:jitan_models/jitan_models.dart';

import '../time_registration/workplace_clock.dart';
import 'time_record_repository.dart';

/// Turns registrations into Time records days (TIME_ENGINE_ANALYSIS D4, D14):
/// pure, no database or clock of its own.
///
/// - A day is an employee's registrations on one workplace-local date.
/// - Each actual row ("Start – actual – QR", …) is paired with the rounded
///   row of the same boundary stored right after it ("Start – rounded"; the
///   two are written in one transaction).
/// - The day's start is its earliest actual start, its finish its latest
///   actual finish.
/// - Status: start and finish → complete; only a start → working today,
///   missing finish on an earlier day; only a finish → missing start.
abstract final class TimeRecordDays {
  static List<TimeRecordDay> build({
    required List<RegistrationRow> rows,
    required Map<int, EmployeeSummary> employees,
    required WorkplaceClock clock,
    required DateTime today,
  }) {
    final byUser = <int, List<RegistrationRow>>{};
    for (final row in rows) {
      byUser.putIfAbsent(row.userId, () => []).add(row);
    }

    final days = <TimeRecordDay>[];
    for (final MapEntry(key: userId, value: userRows) in byUser.entries) {
      final employee = employees[userId];
      if (employee == null) continue;
      final byId = [...userRows]..sort((a, b) => a.id.compareTo(b.id));

      final times = <DateTime, ({List<TimeRecordTime> starts, List<TimeRecordTime> finishes})>{};
      for (final row in byId) {
        final actual = _actual(row.typeName);
        if (actual == null) continue;
        final roundedName = actual.boundary == RegistrationBoundary.start ? 'Start – rounded' : 'Finish – rounded';
        final rounded = byId.where((r) => r.id > row.id && r.typeName == roundedName).firstOrNull;
        final time = TimeRecordTime(
          actualId: row.id,
          actual: row.at,
          rounded: rounded?.at,
          method: actual.method,
          enteredByHand: row.manualEntry,
          actualLocal: _hhmm(clock.wallClockOf(row.at)),
          roundedLocal: rounded == null ? null : _hhmm(clock.wallClockOf(rounded.at)),
          reason: row.comment,
        );
        final local = clock.wallClockOf(row.at);
        final date = DateTime.utc(local.year, local.month, local.day);
        final day = times.putIfAbsent(date, () => (starts: [], finishes: []));
        (actual.boundary == RegistrationBoundary.start ? day.starts : day.finishes).add(time);
      }

      for (final MapEntry(key: date, value: day) in times.entries) {
        day.starts.sort((a, b) => a.actual.compareTo(b.actual));
        day.finishes.sort((a, b) => a.actual.compareTo(b.actual));
        final start = day.starts.firstOrNull;
        final finish = day.finishes.lastOrNull;
        days.add(
          TimeRecordDay(
            employeeId: userId,
            firstName: employee.firstName,
            lastName: employee.lastName,
            employeeCode: employee.code,
            date: date,
            status: switch ((start, finish)) {
              (_?, _?) => TimeRecordStatus.complete,
              (_?, null) => date == today ? TimeRecordStatus.working : TimeRecordStatus.missingFinish,
              _ => TimeRecordStatus.missingStart,
            },
            start: start,
            finish: finish,
          ),
        );
      }
    }

    String name(TimeRecordDay d) => '${d.lastName ?? ''} ${d.firstName ?? ''} ${d.employeeCode}'.toLowerCase();
    days.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : name(a).compareTo(name(b));
    });
    return days;
  }

  static String _hhmm(DateTime wallClock) =>
      '${wallClock.hour.toString().padLeft(2, '0')}:${wallClock.minute.toString().padLeft(2, '0')}';

  /// "Start – actual – QR" → (start, qr); `null` for any other type.
  static ({RegistrationBoundary boundary, TimeRecordMethod method})? _actual(String typeName) {
    final match = RegExp(r'^(Start|Finish) – actual – (Geofence|QR|Manual)$').firstMatch(typeName);
    if (match == null) return null;
    return (
      boundary: match.group(1) == 'Start' ? RegistrationBoundary.start : RegistrationBoundary.finish,
      method: switch (match.group(2)) {
        'Geofence' => TimeRecordMethod.geofence,
        'QR' => TimeRecordMethod.qr,
        _ => TimeRecordMethod.manual,
      },
    );
  }
}
