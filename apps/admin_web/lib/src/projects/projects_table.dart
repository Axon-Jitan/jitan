import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'project_text.dart';

/// The Projects table (Figma `647:1192`): a row opens the project, its "⋯"
/// Manage project. A phone keeps the name, the status and the "⋯".
class ProjectsTable extends StatelessWidget {
  const ProjectsTable({super.key, required this.projects, required this.onOpen, required this.onManage});

  final List<ProjectSummary> projects;
  final ValueChanged<ProjectSummary> onOpen;
  final ValueChanged<ProjectSummary> onManage;

  // Column widths proportional to Figma.
  static const _flexProject = 340;
  static const _flexCompany = 230;
  static const _flexTeam = 230;
  static const _flexStatus = 230;
  static const _flexActions = 90;
  static const _flexPhoneProject = 190;
  static const _flexPhoneStatus = 100;
  static const _flexPhoneActions = 48;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return JitanSliverTable(
      minWidth: phone ? 0 : 760,
      onRowTap: (i) => onOpen(projects[i]),
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.projectColumnProject), flex: phone ? _flexPhoneProject : _flexProject),
        if (!phone) ...[
          JitanTableColumn(label: t.t(AdminTextKeys.projectColumnCompany), flex: _flexCompany),
          JitanTableColumn(label: t.t(AdminTextKeys.projectColumnTeam), flex: _flexTeam),
        ],
        JitanTableColumn(label: t.t(AdminTextKeys.projectColumnStatus), flex: phone ? _flexPhoneStatus : _flexStatus),
        JitanTableColumn(label: '', flex: phone ? _flexPhoneActions : _flexActions, align: JitanColumnAlign.end),
      ],
      rowCount: projects.length,
      cells: (i) {
        final project = projects[i];
        return [
          Text(project.name, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong),
          if (!phone) ...[
            Text(project.companyName, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell),
            Text('${project.teamSize}', style: JitanTextStyles.tableCell),
          ],
          JitanStatusLabel(label: project.status.name, isPositive: ProjectText.isRunning(project.status)),
          JitanRowActionsButton(tooltip: t.t(AdminTextKeys.projectActions), onPressed: () => onManage(project)),
        ];
      },
    );
  }
}
