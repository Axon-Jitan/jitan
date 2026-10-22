/// "Registered today" while the employee is still working: the time since
/// the start, minus the part of the break already passed (D13: the break is
/// deducted automatically; D28 places it in the middle of the day).
///
/// Display only (CLAUDE.md, architecture rule 2): it is never stored or
/// sent. Once the day is finished the server's registered time is shown
/// instead (rounded finish − rounded start − break), which this total meets
/// after the break has passed.
abstract final class RunningTotal {
  /// Whole minutes from [start] to [now], minus the overlap with the break
  /// from [breakStart] to [breakFinish] (`HH:mm` on [now]'s day, local time);
  /// never below zero. Without a break window nothing is deducted.
  static int minutes({required DateTime start, required DateTime now, String? breakStart, String? breakFinish}) {
    final from = start.toLocal(), to = now.toLocal();
    if (!to.isAfter(from)) return 0;
    var worked = to.difference(from).inMinutes;
    final breakFrom = _at(to, breakStart), breakTo = _at(to, breakFinish);
    if (breakFrom != null && breakTo != null && breakTo.isAfter(breakFrom)) {
      final overlapStart = from.isAfter(breakFrom) ? from : breakFrom;
      final overlapEnd = to.isBefore(breakTo) ? to : breakTo;
      if (overlapEnd.isAfter(overlapStart)) worked -= overlapEnd.difference(overlapStart).inMinutes;
    }
    return worked < 0 ? 0 : worked;
  }

  static DateTime? _at(DateTime day, String? hhmm) {
    final match = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    if (match == null) return null;
    return DateTime(day.year, day.month, day.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
  }
}
