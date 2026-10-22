import 'package:flutter/widgets.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';

/// The words of "Today" that depend on data or the time of day.
abstract final class TodayText {
  /// Figma 1452:2: "Good morning" before 12:00, "Good afternoon" until
  /// 18:00, "Good evening" after, in the phone's local time, followed by the
  /// first name (`tblUser.userName`); without one, the greeting alone.
  static String greeting(BuildContext context, String? firstName, DateTime now) {
    final named = firstName != null && firstName.trim().isNotEmpty;
    final key = switch (now.hour) {
      < 12 => named ? EmployeeTextKeys.todayGreetingMorning : EmployeeTextKeys.todayGreetingMorningNoName,
      < 18 => named ? EmployeeTextKeys.todayGreetingAfternoon : EmployeeTextKeys.todayGreetingAfternoonNoName,
      _ => named ? EmployeeTextKeys.todayGreetingEvening : EmployeeTextKeys.todayGreetingEveningNoName,
    };
    return context.t(key, args: {if (named) 'name': firstName.trim()});
  }

  /// "8h 07m".
  static String duration(BuildContext context, int minutes) => context.t(
    EmployeeTextKeys.todayDuration,
    args: {'hours': minutes ~/ 60, 'minutes': (minutes % 60).toString().padLeft(2, '0')},
  );

  static String method(BuildContext context, TimeRecordMethod method) => context.t(switch (method) {
    TimeRecordMethod.manual => EmployeeTextKeys.todayMethodManual,
    TimeRecordMethod.qr => EmployeeTextKeys.todayMethodQr,
    TimeRecordMethod.geofence => EmployeeTextKeys.todayMethodGeofence,
  });

  /// "08:00 — 16:30"; a time that is not there is "--:--".
  static String range(String? start, String? finish) => '${start ?? '--:--'} — ${finish ?? '--:--'}';
}

/// The start or finish of [day] as the employee sees it: what counts, or the
/// correction waiting for HR (D31).
({String? local, DateTime? at, bool pending}) shownTime(TimeRecordDay? day, RegistrationBoundary boundary) {
  final request = day?.pending.where((p) => p.boundary == boundary).firstOrNull;
  if (request != null) return (local: request.requestedLocal, at: request.requested, pending: true);
  final time = boundary == RegistrationBoundary.start ? day?.start : day?.finish;
  return (local: time?.actualLocal, at: time?.rounded ?? time?.actual, pending: false);
}
