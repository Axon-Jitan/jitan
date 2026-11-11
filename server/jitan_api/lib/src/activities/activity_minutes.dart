import 'package:jitan_models/jitan_models.dart';

import '../time_registration/workplace_clock.dart';

/// A stretch of a day in workplace minutes since midnight: from, to.
typedef MinuteSpan = (int, int);

/// How long an activity counts for (D34, D46): pure, shared by Today's
/// breakdown and the project report.
abstract final class ActivityMinutes {
  /// From each finish to the next start of [day]: nothing counts for any
  /// activity then (D34).
  static List<MinuteSpan> timeAway(TimeRecordDay? day) {
    final events = [
      for (final event in day?.events ?? const <TimeRecordEvent>[])
        if (event.active && event.kind == TimeRecordEventKind.registered) event,
    ]..sort((a, b) => a.atLocal.compareTo(b.atLocal));
    final away = <MinuteSpan>[];
    int? finished;
    for (final event in events) {
      final at = minuteOf(event.atLocal);
      if (event.boundary == RegistrationBoundary.finish) {
        finished = at;
      } else if (finished != null) {
        away.add((finished, at));
        finished = null;
      }
    }
    return away;
  }

  /// Whole minutes from [from] to [to], without the minutes in [left].
  static int between(WorkplaceClock clock, DateTime from, DateTime to, List<MinuteSpan> left) {
    final local = clock.wallClockOf(from), localEnd = clock.wallClockOf(to);
    final start = local.hour * 60 + local.minute, end = localEnd.hour * 60 + localEnd.minute;
    var minutes = to.difference(from).inMinutes;
    for (final (out, back) in left) {
      final overlapStart = out > start ? out : start, overlapEnd = back < end ? back : end;
      if (overlapEnd > overlapStart) minutes -= overlapEnd - overlapStart;
    }
    return minutes < 0 ? 0 : minutes;
  }

  /// `HH:mm` → minutes since midnight.
  static int minuteOf(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
}
