import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'project_text.dart';

/// The Projects table (Figma `1512:2`): a row opens the project. A phone keeps
/// the project and its status.
class ProjectsTable extends StatelessWidget {
  const ProjectsTable({super.key, required this.projects, required this.now, required this.onOpen});

  final List<ProjectSummary> projects;
  final DateTime now;
  final ValueChanged<ProjectSummary> onOpen;

  // Column widths proportional to Figma.
  static const _flexProject = 380;
  static const _flexPlace = 330;
  static const _flexStatus = 160;
  static const _flexUsed = 176;
  static const _flexOpen = 30;
  static const _flexPhoneProject = 190;
  static const _flexPhoneStatus = 110;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(projects[i]),
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.projectColumnProject), flex: phone ? _flexPhoneProject : _flexProject),
        if (!phone) JitanTableColumn(label: t.t(AdminTextKeys.projectColumnPlace), flex: _flexPlace),
        JitanTableColumn(label: t.t(AdminTextKeys.projectColumnStatus), flex: phone ? _flexPhoneStatus : _flexStatus),
        if (!phone) JitanTableColumn(label: t.t(AdminTextKeys.projectColumnLastUsed), flex: _flexUsed),
        const JitanTableColumn(label: '', flex: _flexOpen, align: JitanColumnAlign.end),
      ],
      rowCount: projects.length,
      cells: (i) {
        final project = projects[i];
        return [
          Text(project.fullName, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong),
          if (!phone) Text(ProjectText.place(context, project), overflow: TextOverflow.ellipsis, style: muted),
          Row(
            spacing: 8,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: project.isActive ? JitanColors.success : JitanColors.inkMuted,
                  shape: BoxShape.circle,
                ),
              ),
              Flexible(
                child: Text(
                  context.t(project.isActive ? AdminTextKeys.projectActive : AdminTextKeys.projectInactive),
                  overflow: TextOverflow.ellipsis,
                  style: project.isActive ? JitanTextStyles.tableCell : muted,
                ),
              ),
            ],
          ),
          if (!phone) Text(ProjectText.lastUsed(context, project.lastUsed, now), overflow: TextOverflow.ellipsis, style: muted),
          const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ];
      },
      footer: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.tPlural(AdminTextKeys.projectsCount, projects.length), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
      ),
    );
  }
}
