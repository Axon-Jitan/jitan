import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedule_summary_text.dart';

/// What HR picked in "Manage schedules".
enum ScheduleRowAction { edit, openGroup, removeWorkHours, removeBreaks }

/// The Schedules table (Figma `HR / Schedules — One row per group` 1458:2):
/// group, days and hours, break, rounding and status. A click on
/// a row opens the group's page; "···" opens Manage schedules.
class SchedulesTable extends StatelessWidget {
  const SchedulesTable({super.key, required this.rows, required this.onManage, required this.onOpen});

  final List<ScheduleRow> rows;
  final ValueChanged<ScheduleRow> onManage;
  final ValueChanged<ScheduleRow> onOpen;

  /// Proportional to Figma (210 / 300 / 120 / 190 / 140 / 46).
  static const _flex = [210, 300, 120, 190, 140, 46];

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(rows[i]),
      columns: [
        for (final (i, key) in [
          AdminTextKeys.scheduleColumnName,
          AdminTextKeys.scheduleColumnDaysHours,
          AdminTextKeys.scheduleColumnBreak,
          AdminTextKeys.scheduleColumnRounding,
          AdminTextKeys.scheduleColumnStatus,
        ].indexed)
          JitanTableColumn(label: t.t(key), flex: _flex[i]),
        JitanTableColumn(label: '', flex: _flex[5], align: JitanColumnAlign.end),
      ],
      rowCount: rows.length,
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Text(
          context.tPlural(AdminTextKeys.scheduleListCount, rows.length),
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 13),
        ),
      ),
      cells: (i) => _cells(t, rows[i]),
    );
  }

  List<Widget> _cells(Translations t, ScheduleRow row) {
    final variant = row.variant;
    final none = t.t(CommonTextKeys.valueUnavailable);
    final daysAndHours = switch (variant) {
      null => t.t(AdminTextKeys.scheduleSettingDiffer),
      _ when !row.hasWorkHours => none,
      final v => workHoursDaysSummary(t, v),
    };
    final lengths = {for (final b in variant?.breaks ?? const <BreakSchedule>[]) b.lengthMinutes};
    final breaks = switch (variant) {
      null => none,
      _ when lengths.isEmpty => none,
      _ when lengths.length == 1 => t.t(AdminTextKeys.scheduleBreakMinutes, args: {'minutes': lengths.single}),
      final v => breaksSummary(t, v),
    };
    final first = variant?.workDays.where((d) => d.start != null && d.finish != null).firstOrNull;
    final rounding = first == null ? none : roundingPairText(t, first.start!.rounding, first.finish!.rounding);
    Widget cell(String text, {bool strong = false}) => Tooltip(
      message: text,
      child: Text(text, style: strong ? JitanTextStyles.tableCellStrong : JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis),
    );
    return [
      cell(row.group.name, strong: true),
      cell(daysAndHours),
      cell(breaks),
      cell(rounding),
      JitanStatusLabel(
        label: t.t(row.status == ScheduleRowStatus.active ? CommonTextKeys.statusActive : AdminTextKeys.scheduleStatusDiffer),
        isPositive: row.status == ScheduleRowStatus.active,
        color: row.status == ScheduleRowStatus.active ? null : JitanColors.warning,
      ),
      JitanRowActionsButton(tooltip: t.t(AdminTextKeys.scheduleActionsMenu), onPressed: () => onManage(row)),
    ];
  }
}
