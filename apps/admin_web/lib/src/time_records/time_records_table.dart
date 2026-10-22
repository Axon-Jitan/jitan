import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_record_text.dart';

/// The Time records table (Figma `160:2`): employee, date, rounded and actual
/// time, method, status and "View →" (the day detail, `160:94`), as a
/// [JitanSliverTable].
///
/// Differences from Figma, on purpose:
/// - **Pending review** and **Corrected** are not shown: the ERD stores no
///   review state, and HR corrections come with the next slice.
/// - The action is "View" on every row; "Fix" and "Review" arrive with HR
///   corrections, so no row offers an action that can not be done yet.
/// - A day still in progress shows **Working** (product owner, 2026-10-22).
class TimeRecordsTable extends StatelessWidget {
  const TimeRecordsTable({super.key, required this.days, required this.onView});

  final List<TimeRecordDay> days;
  final ValueChanged<TimeRecordDay> onView;

  /// Proportional to Figma (x = 20/210/320/460/600/720/880 in a 1120 px card).
  static const _flex = [190, 110, 140, 140, 120, 160, 100];

  @override
  Widget build(BuildContext context) => JitanSliverTable(
    columns: [
      for (final (i, key) in [
        AdminTextKeys.timeRecordsColumnEmployee,
        AdminTextKeys.timeRecordsColumnDate,
        AdminTextKeys.timeRecordsColumnRounded,
        AdminTextKeys.timeRecordsColumnActual,
        AdminTextKeys.timeRecordsColumnMethod,
        AdminTextKeys.timeRecordsColumnStatus,
      ].indexed)
        JitanTableColumn(label: context.t(key), flex: _flex[i]),
      JitanTableColumn(label: context.t(AdminTextKeys.timeRecordsColumnAction), flex: _flex[6], align: JitanColumnAlign.end),
    ],
    rowCount: days.length,
    cells: (i) => _cells(context, days[i]),
  );

  List<Widget> _cells(BuildContext context, TimeRecordDay day) {
    final method = day.start?.method ?? day.finish?.method;
    return [
      Text(TimeRecordText.name(day), style: JitanTextStyles.tableCellStrong, overflow: TextOverflow.ellipsis),
      Text(TimeRecordText.shortDate(context, day.date), style: JitanTextStyles.tableCell),
      Text(TimeRecordText.range(day.start?.roundedLocal, day.finish?.roundedLocal), style: JitanTextStyles.tableCell),
      Text(TimeRecordText.range(day.start?.actualLocal, day.finish?.actualLocal), style: JitanTextStyles.tableCell),
      Text(method == null ? '—' : TimeRecordText.method(context, method), style: JitanTextStyles.tableCell),
      JitanStatusLabel(
        label: TimeRecordText.status(context, day.status),
        isPositive: day.status == TimeRecordStatus.complete,
        color: TimeRecordText.statusColor(day.status),
      ),
      TextButton(
        onPressed: () => onView(day),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.t(AdminTextKeys.timeRecordsView),
                style: JitanTextStyles.tableCellStrong,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 16, color: JitanColors.ink),
          ],
        ),
      ),
    ];
  }
}
