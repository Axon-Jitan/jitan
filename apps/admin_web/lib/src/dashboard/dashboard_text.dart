import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The words and numbers of the Dashboard.
abstract final class DashboardText {
  /// "3,127".
  static String number(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');

  /// Whole hours: "3,127h".
  static String hours(BuildContext context, int minutes) =>
      context.t(AdminTextKeys.reportHours, args: {'hours': number((minutes / 60).round())});

  /// "Saturday 31 October".
  static String longDate(BuildContext context, DateTime date) =>
      '${context.t(CommonTextKeys.weekdayLong[date.weekday - 1])} ${date.day} '
      '${context.t(CommonTextKeys.monthLong[date.month - 1])}';

}
