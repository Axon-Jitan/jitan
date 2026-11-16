import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';

/// The hours Jitan registers in, in the workplace's local time (product
/// owner, 2026-11-16, D52): only day shifts, from 05:00 to 19:00. A start,
/// finish, scan, switch or trip outside them is not registered; the employee
/// sees HR, who corrects the day. HR's own corrections are not limited. Also
/// keeps rounding from moving a time past midnight (review L2).
abstract final class WorkingHours {
  static const earliestMinute = 5 * 60;
  static const latestMinute = 19 * 60;

  /// Whether the local wall-clock time [local] is within the hours, both
  /// ends included.
  static bool contains(DateTime local) {
    final minute = local.hour * 60 + local.minute;
    final second = local.second + local.millisecond + local.microsecond;
    return minute >= earliestMinute && (minute < latestMinute || (minute == latestMinute && second == 0));
  }

  /// 400 `outside_working_hours` unless [local] is within the hours.
  static void require(DateTime local) {
    if (!contains(local)) {
      throw const ApiException(
        400,
        ApiErrorCode.outsideWorkingHours,
        'Jitan registers times from 05:00 to 19:00. Please see HR.',
      );
    }
  }
}
