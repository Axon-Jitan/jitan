import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// How a period and its days are written, on the Dashboard and in Reports.
abstract final class PeriodText {
  static String _month(BuildContext context, DateTime date) => context.t(CommonTextKeys.monthShort[date.month - 1]);

  /// "26 Oct".
  static String shortDate(BuildContext context, DateTime date) => '${date.day} ${_month(context, date)}';

  /// "25 Oct 2026".
  static String date(BuildContext context, DateTime date) => '${shortDate(context, date)} ${date.year}';

  /// "25 – 31 Oct 2026", "28 Sep – 4 Oct 2026", "31 Oct 2026".
  static String range(BuildContext context, DateTime from, DateTime to) {
    if (from == to) return date(context, to);
    if (from.year != to.year) return '${date(context, from)} – ${date(context, to)}';
    if (from.month != to.month) return '${shortDate(context, from)} – ${date(context, to)}';
    return '${from.day} – ${date(context, to)}';
  }

  /// "25 Oct 2026" back to a date; `null` when it isn't one.
  static DateTime? parseDate(BuildContext context, String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]), year = int.tryParse(parts[2]);
    final name = parts[1].toLowerCase();
    final month = [
      for (final key in CommonTextKeys.monthShort) context.t(key).toLowerCase(),
    ].indexOf(name) + 1;
    if (day == null || year == null || month == 0) return null;
    final date = DateTime(year, month, day);
    return date.month == month ? date : null;
  }
}
