import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'project_text.dart';

/// The Projects table (Figma `HR / Projects V2 — page` `1562:2`): project,
/// place, last used and status. A row opens the project, with a › while
/// hovered; an inactive project is muted. A phone keeps the project and its
/// status.
class ProjectsTable extends StatelessWidget {
  const ProjectsTable({super.key, required this.projects, required this.now, required this.onOpen});

  final List<ProjectSummary> projects;
  final DateTime now;
  final ValueChanged<ProjectSummary> onOpen;

  /// As Figma (440 / 220 / 220 / 200).
  static const _flex = [440, 220, 220, 200];
  static const _flexPhone = [190, 120];

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final keys = [
      AdminTextKeys.projectColumnProject,
      if (!phone) ...[AdminTextKeys.projectColumnPlace, AdminTextKeys.projectColumnLastUsed],
      AdminTextKeys.projectColumnStatus,
    ];
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(projects[i]),
      hoverChevron: true,
      columns: [
        for (final (i, key) in keys.indexed) JitanTableColumn(label: t.t(key), flex: (phone ? _flexPhone : _flex)[i]),
      ],
      rowCount: projects.length,
      cells: (i) {
        final project = projects[i];
        final muted = project.isActive ? null : JitanColors.inkMuted;
        return [
          Text(project.fullName, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong.copyWith(color: muted)),
          if (!phone) ...[
            Text(ProjectText.place(context, project), overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell.copyWith(color: muted)),
            Text(
              ProjectText.lastUsed(context, project.lastUsed, now),
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
          ],
          JitanStatusLabel(
            label: context.t(project.isActive ? AdminTextKeys.projectActive : AdminTextKeys.projectInactive),
            isPositive: project.isActive,
          ),
        ];
      },
    );
  }
}
