import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The small "Late" or "Left early" mark after a finished day's status
/// (Figma `1521:2`), in the Dashboard's Attendance colours. A day on time has
/// none.
class AttendanceMark extends StatelessWidget {
  const AttendanceMark({super.key, required this.attendance});

  final DayAttendance attendance;

  /// The light background behind each colour.
  static const _lateSurface = Color(0xFFFFF1DC);
  static const _leftEarlySurface = Color(0xFFF0EEFC);

  @override
  Widget build(BuildContext context) {
    final (key, color, surface) = switch (attendance) {
      DayAttendance.late => (AdminTextKeys.timeRecordsAttendanceLate, JitanColors.warning, _lateSurface),
      DayAttendance.leftEarly => (AdminTextKeys.timeRecordsAttendanceLeftEarly, JitanColors.chartViolet, _leftEarlySurface),
      DayAttendance.onTime => (AdminTextKeys.timeRecordsAttendanceOnTime, JitanColors.success, JitanColors.successSurface),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          context.t(key),
          maxLines: 1,
          style: JitanTextStyles.tableCell.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: color),
        ),
      ),
    );
  }
}
