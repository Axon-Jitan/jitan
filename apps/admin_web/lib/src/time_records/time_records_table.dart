import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_correction_flow.dart';
import 'time_record_text.dart';

/// The Time records table (Figma `160:2`): employee, date, rounded and actual
/// time, method, status and the action, as a [JitanSliverTable]. The action
/// is "Fix" for a missing start or finish or a day without registration,
/// "Review" for an employee's correction waiting for HR (D31), and "View"
/// (the day detail, `160:94`) otherwise.
///
/// Difference from Figma, on purpose: a day still in progress shows
/// **Working** (product owner, 2026-10-22).
class TimeRecordsTable extends StatelessWidget {
  const TimeRecordsTable({super.key, required this.days, required this.onView, required this.onCorrect, required this.mayCorrect});

  final List<TimeRecordDay> days;
  final ValueChanged<TimeRecordDay> onView;
  final void Function(TimeRecordDay day, TimeCorrectionStep step) onCorrect;

  /// `false` when the day can not be corrected here: the row offers "View".
  final bool Function(TimeRecordDay day) mayCorrect;

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
    final step = mayCorrect(day) ? TimeCorrectionStep.forRow(day) : null;
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
        onPressed: () => step == null ? onView(day) : onCorrect(day, step),
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.t(switch (step) {
                  TimeCorrectionStep.review => AdminTextKeys.timeRecordsReview,
                  TimeCorrectionStep.resolve || TimeCorrectionStep.correct => AdminTextKeys.timeRecordsFix,
                  null => AdminTextKeys.timeRecordsView,
                }),
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
