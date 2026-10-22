import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedule_summary_text.dart';

/// What HR picked in "Manage schedules".
enum ScheduleRowAction { edit, deactivate }

/// The "Group schedules" table (Figma `HR / Schedules — Manage actions`
/// 1359:27): one row per group and kind; "···" opens Manage schedules.
class SchedulesTable extends StatelessWidget {
  const SchedulesTable({super.key, required this.rows, required this.onManage});

  final List<ScheduleRow> rows;
  final ValueChanged<ScheduleRow> onManage;

  /// Column widths proportional to Figma (x = 20/425/926/1040 in a 1120 px
  /// card).
  static const _flexName = 405;
  static const _flexDaysHours = 501;
  static const _flexStatus = 114;
  static const _flexActions = 80;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnName), flex: _flexName),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnDaysHours), flex: _flexDaysHours),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnStatus), flex: _flexStatus),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnActions), flex: _flexActions, align: JitanColumnAlign.end),
      ],
      rowCount: rows.length,
      cells: (i) => _cells(t, rows[i]),
    );
  }

  List<Widget> _cells(Translations t, ScheduleRow row) {
    final kind = t.t(row.kind == ScheduleKind.workHours ? AdminTextKeys.scheduleKindWorkHours : AdminTextKeys.scheduleKindBreaks);
    final daysAndHours = switch (row.variant) {
      null => t.t(AdminTextKeys.scheduleSettingDiffer),
      final variant when row.kind == ScheduleKind.workHours => workHoursDaysSummary(t, variant),
      final variant => breaksSummary(t, variant),
    };
    return [
      Text(
        t.t(AdminTextKeys.scheduleRowName, args: {'group': row.group.name, 'kind': kind}),
        style: JitanTextStyles.tableCellStrong,
        overflow: TextOverflow.ellipsis,
      ),
      Tooltip(
        message: daysAndHours,
        child: Text(daysAndHours, style: JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis),
      ),
      JitanStatusLabel(
        label: t.t(row.status == ScheduleRowStatus.active ? CommonTextKeys.statusActive : AdminTextKeys.scheduleStatusDiffer),
        isPositive: row.status == ScheduleRowStatus.active,
      ),
      JitanRowActionsButton(tooltip: t.t(AdminTextKeys.scheduleActionsMenu), onPressed: () => onManage(row)),
    ];
  }
}
