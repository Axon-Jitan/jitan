import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The words and numbers of the Reports page.
abstract final class ReportText {
  /// "158h 30m", "160h".
  static String hours(BuildContext context, int minutes) {
    final m = minutes.abs() % 60;
    return context.t(
      m == 0 ? AdminTextKeys.reportHours : AdminTextKeys.reportHoursMinutes,
      args: {'hours': minutes.abs() ~/ 60, 'minutes': m.toString().padLeft(2, '0')},
    );
  }

  /// "+6h", "−1h 30m", "0h".
  static String difference(BuildContext context, int minutes) =>
      '${minutes > 0 ? '+' : minutes < 0 ? '−' : ''}${hours(context, minutes)}';

  /// "52h 15m" of travel; "—" without any (D46).
  static String travel(BuildContext context, HoursReportEmployee e) =>
      e.travelMinutes == 0 ? '—' : hours(context, e.travelMinutes);

  /// "1 268 km"; "—" without trips.
  static String kilometres(BuildContext context, HoursReportEmployee e) {
    if (e.trips == 0) return '—';
    final km = (e.distanceMetres / 1000).round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ' ');
    return context.t(AdminTextKeys.reportKilometres, args: {'km': km});
  }

  /// "October 2026" for `2026-10`.
  static String month(BuildContext context, String month) {
    final [year, number] = month.split('-');
    return '${context.t(CommonTextKeys.monthLong[int.parse(number) - 1])} $year';
  }

  /// "Thu 22 October".
  static String day(BuildContext context, DateTime date) =>
      '${context.t(CommonTextKeys.weekdayShort[date.weekday - 1])} ${date.day} '
      '${context.t(CommonTextKeys.monthLong[date.month - 1])}';

  static String name(HoursReportEmployee e) {
    final name = [e.firstName, e.lastName].whereType<String>().where((n) => n.isNotEmpty).join(' ');
    return name.isEmpty ? e.code : name;
  }

  /// [today]'s month and the twelve before it, newest first, as `yyyy-MM`.
  static List<String> recentMonths(DateTime today) => [
    for (var i = 0; i < 13; i++) monthOf(DateTime(today.year, today.month - i)),
  ];

  static String monthOf(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';
}
