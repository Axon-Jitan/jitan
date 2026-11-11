import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'schedule_rows.dart';
import 'schedule_summary_text.dart';

/// The Schedules table (Figma `HR / Schedules V2 — page` `1547:2`): group,
/// days and hours, break and status. A click on a row opens its pop-up. A
/// phone keeps the group and its days and hours.
class SchedulesTable extends StatelessWidget {
  const SchedulesTable({super.key, required this.rows, required this.onOpen});

  final List<ScheduleRow> rows;
  final ValueChanged<ScheduleRow> onOpen;

  /// As Figma (440 / 220 / 220 / 200).
  static const _flex = [440, 220, 220, 200];
  static const _flexPhone = [150, 190];

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final keys = [
      AdminTextKeys.scheduleColumnName,
      AdminTextKeys.scheduleColumnDaysHours,
      if (!phone) ...[AdminTextKeys.scheduleColumnBreak, AdminTextKeys.scheduleColumnStatus],
    ];
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(rows[i]),
      hoverChevron: true,
      columns: [
        for (final (i, key) in keys.indexed) JitanTableColumn(label: t.t(key), flex: (phone ? _flexPhone : _flex)[i]),
      ],
      rowCount: rows.length,
      cells: (i) => _cells(t, rows[i], phone: phone),
    );
  }

  List<Widget> _cells(Translations t, ScheduleRow row, {required bool phone}) {
    final variant = row.variant;
    final none = t.t(CommonTextKeys.valueUnavailable);
    final daysAndHours = switch (variant) {
      null => t.t(AdminTextKeys.scheduleStatusDiffer),
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
    Widget cell(String text, {bool strong = false}) => Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: strong ? JitanTextStyles.tableCellStrong : JitanTextStyles.tableCell,
    );
    final active = row.status == ScheduleRowStatus.active;
    return [
      cell(row.group.name, strong: true),
      cell(daysAndHours),
      if (!phone) ...[
        cell(breaks),
        JitanStatusLabel(
          label: t.t(active ? CommonTextKeys.statusActive : AdminTextKeys.scheduleStatusDiffer),
          isPositive: active,
          color: active ? null : JitanColors.warning,
        ),
      ],
    ];
  }
}
