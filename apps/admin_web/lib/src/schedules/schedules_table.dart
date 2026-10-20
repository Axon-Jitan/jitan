import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedule_summary_text.dart';

/// What HR picked in a row's "···" menu.
enum ScheduleRowAction { edit, deactivate }

/// The "Employee schedules" table (Figma `HR / Schedules — Deactivate
/// confirmation` 1320:579): one row per group and kind.
class SchedulesTable extends StatelessWidget {
  const SchedulesTable({super.key, required this.rows, required this.onAction});

  final List<ScheduleRow> rows;
  final void Function(ScheduleRow row, ScheduleRowAction action) onAction;

  /// Column widths proportional to Figma (x = 20/268/465/705/930/1048 in a
  /// 1120 px card).
  static const _flexName = 248;
  static const _flexType = 197;
  static const _flexGroup = 240;
  static const _flexSetting = 225;
  static const _flexStatus = 118;
  static const _flexActions = 72;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanDataTable(
      minWidth: 960,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnName), flex: _flexName),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnType), flex: _flexType),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnGroup), flex: _flexGroup),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnSetting), flex: _flexSetting),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnStatus), flex: _flexStatus),
        JitanTableColumn(label: t.t(AdminTextKeys.scheduleColumnActions), flex: _flexActions),
      ],
      rows: [for (final row in rows) _cells(context, t, row)],
    );
  }

  List<Widget> _cells(BuildContext context, Translations t, ScheduleRow row) {
    final kind = t.t(row.kind == ScheduleKind.workHours ? AdminTextKeys.scheduleKindWorkHours : AdminTextKeys.scheduleKindBreaks);
    final setting = switch (row.variant) {
      null => t.t(AdminTextKeys.scheduleSettingDiffer),
      final variant when row.kind == ScheduleKind.workHours => workHoursSummary(t, variant),
      final variant => breaksSummary(t, variant),
    };
    return [
      Text(
        t.t(AdminTextKeys.scheduleRowName, args: {'group': row.group.name, 'kind': kind}),
        style: JitanTextStyles.tableCellStrong,
        overflow: TextOverflow.ellipsis,
      ),
      Text(kind, style: JitanTextStyles.tableCell),
      Text(row.group.name, style: JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis),
      Tooltip(
        message: setting,
        child: Text(setting, style: JitanTextStyles.tableCell, overflow: TextOverflow.ellipsis, maxLines: 2),
      ),
      JitanStatusLabel(
        label: t.t(row.status == ScheduleRowStatus.active ? CommonTextKeys.statusActive : AdminTextKeys.scheduleStatusDiffer),
        isPositive: row.status == ScheduleRowStatus.active,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: PopupMenuButton<ScheduleRowAction>(
          tooltip: t.t(AdminTextKeys.scheduleActionsMenu),
          icon: const Icon(Icons.more_horiz, size: 18, color: JitanColors.ink),
          onSelected: (action) => onAction(row, action),
          itemBuilder: (_) => [
            PopupMenuItem(value: ScheduleRowAction.edit, child: Text(t.t(AdminTextKeys.scheduleActionEdit))),
            PopupMenuItem(value: ScheduleRowAction.deactivate, child: Text(t.t(AdminTextKeys.scheduleActionDeactivate))),
          ],
        ),
      ),
    ];
  }
}
