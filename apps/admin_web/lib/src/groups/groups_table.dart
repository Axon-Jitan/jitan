import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'group_schedule_text.dart';

/// The Groups table (Figma `HR / Groups V2 — page` `1554:2`): name,
/// employees, schedule and status. A row opens the group's page, with a ›
/// while hovered; an inactive group is muted. A phone keeps the name and
/// the employees.
class GroupsTable extends StatelessWidget {
  const GroupsTable({super.key, required this.groups, required this.schedules, required this.onOpen});

  final List<GroupOverview> groups;
  final Map<int, GroupSchedule> schedules;

  /// A click on the row: the group's page.
  final ValueChanged<GroupOverview> onOpen;

  /// As Figma (440 / 220 / 200 / 200).
  static const _flex = [440, 220, 200, 200];
  static const _flexPhone = [190, 120];

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final keys = [
      AdminTextKeys.groupsColumnName,
      AdminTextKeys.groupsColumnEmployees,
      if (!phone) ...[AdminTextKeys.groupsColumnSchedule, AdminTextKeys.groupsColumnStatus],
    ];
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(groups[i]),
      hoverChevron: true,
      columns: [
        for (final (i, key) in keys.indexed) JitanTableColumn(label: t.t(key), flex: (phone ? _flexPhone : _flex)[i]),
      ],
      rowCount: groups.length,
      cells: (i) {
        final group = groups[i];
        final muted = group.isActive ? null : JitanColors.inkMuted;
        final schedule = schedules[group.id];
        final hasHours = schedule != null && groupHasOwnHours(schedule);
        return [
          Text(group.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong.copyWith(color: muted)),
          Text('${group.employeeCount}', style: JitanTextStyles.tableCell.copyWith(color: muted)),
          if (!phone) ...[
            Text(
              groupScheduleText(t, schedule),
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCell.copyWith(color: hasHours ? muted : JitanColors.inkMuted),
            ),
            JitanStatusLabel(
              label: t.t(group.isActive ? CommonTextKeys.statusActive : CommonTextKeys.statusInactive),
              isPositive: group.isActive,
            ),
          ],
        ];
      },
    );
  }
}
