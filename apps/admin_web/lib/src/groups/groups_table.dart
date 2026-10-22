import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'group_schedule_text.dart';

/// The Employee groups table (Figma `HR / Employee groups — Overview`
/// 1340:2): name, employees, schedule, status and "⋯". A row click opens
/// nothing in V1 (product owner, 2026-10-21: details from a row come in V2).
class GroupsTable extends StatelessWidget {
  const GroupsTable({super.key, required this.groups, required this.schedules, required this.onManage, required this.onOpen});

  final List<GroupOverview> groups;
  final Map<int, GroupSchedule> schedules;
  final ValueChanged<GroupOverview> onManage;

  /// A click on the row: the group's page (Figma `1455:2`).
  final ValueChanged<GroupOverview> onOpen;

  /// Column widths proportional to Figma (x = 20/366/586/916/1080 in a 1120
  /// px card).
  static const _flexName = 346;
  static const _flexEmployees = 220;
  static const _flexSchedule = 330;
  static const _flexStatus = 134;
  static const _flexActions = 70;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(groups[i]),
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.groupsColumnName), flex: _flexName),
        JitanTableColumn(label: t.t(AdminTextKeys.groupsColumnEmployees), flex: _flexEmployees),
        JitanTableColumn(label: t.t(AdminTextKeys.groupsColumnSchedule), flex: _flexSchedule),
        JitanTableColumn(label: t.t(AdminTextKeys.groupsColumnStatus), flex: _flexStatus),
        JitanTableColumn(
          label: t.t(AdminTextKeys.groupsColumnActions),
          flex: _flexActions,
          align: JitanColumnAlign.end,
        ),
      ],
      rowCount: groups.length,
      cells: (i) {
        final group = groups[i];
        return [
          Text(group.name, style: JitanTextStyles.tableCellStrong),
          Text('${group.employeeCount}', style: JitanTextStyles.tableCell),
          Text(groupScheduleText(t, schedules[group.id]), style: JitanTextStyles.tableCell),
          JitanStatusLabel(
            label: t.t(group.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
            isPositive: group.isActive,
          ),
          JitanRowActionsButton(tooltip: t.t(AdminTextKeys.groupsActionsMenu), onPressed: () => onManage(group)),
        ];
      },
    );
  }
}
