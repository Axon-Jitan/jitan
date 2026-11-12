import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'report_text.dart';

/// One row per project (Figma `HR / Reports V2 — projects` `1571:390`): a row
/// opens the project's period, with a › while hovered. On a phone only the
/// project and its worked hours.
class ProjectReportsTable extends StatelessWidget {
  const ProjectReportsTable({super.key, required this.projects, required this.onOpen});

  final List<ProjectReportProject> projects;
  final ValueChanged<ProjectReportProject> onOpen;

  /// Column widths proportional to Figma.
  static const _flexProject = 270;
  static const _flexNumber = 130;
  static const _flexTrips = 110;
  static const _flexPhoneProject = 200;
  static const _flexPhoneHours = 90;
  static const _flexPhoneOpen = 44;

  static final _muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    if (MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint) return _phone(context, t);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(projects[i]),
      hoverChevron: true,
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.reportColumnProject), flex: _flexProject),
        JitanTableColumn(label: t.t(AdminTextKeys.reportColumnEmployees), flex: _flexNumber),
        JitanTableColumn(label: t.t(AdminTextKeys.reportRegistered), flex: _flexNumber),
        JitanTableColumn(label: t.t(AdminTextKeys.reportTravel), flex: _flexNumber),
        JitanTableColumn(label: t.t(AdminTextKeys.reportColumnTrips), flex: _flexTrips),
        JitanTableColumn(label: t.t(AdminTextKeys.reportColumnKilometres), flex: _flexNumber),
      ],
      rowCount: projects.length,
      cells: (i) {
        final p = projects[i];
        return [
          _name(p),
          Text('${p.employees.length}', style: JitanTextStyles.tableCell),
          Text(ReportText.hours(context, p.workedMinutes), style: JitanTextStyles.tableCellStrong),
          Text(ReportText.hoursOrNone(context, p.travelMinutes), style: p.travelMinutes == 0 ? _muted : JitanTextStyles.tableCell),
          Text(p.trips == 0 ? '—' : '${p.trips}', style: p.trips == 0 ? _muted : JitanTextStyles.tableCell),
          Text(
            ReportText.distance(context, p.trips, p.distanceMetres),
            style: p.tripsWithoutDistance > 0
                ? JitanTextStyles.tableCell.copyWith(color: JitanColors.warning)
                : (p.trips == 0 ? _muted : JitanTextStyles.tableCell),
          ),
        ];
      },
    );
  }

  Widget _name(ProjectReportProject p) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: p.project.fullName, style: JitanTextStyles.tableCellStrong),
        if (p.project.placeName case final place? when place.isNotEmpty)
          TextSpan(text: '  $place', style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
      ],
    ),
    overflow: TextOverflow.ellipsis,
  );

  Widget _phone(BuildContext context, Translations t) => JitanSliverTable(
    minWidth: 0,
    onRowTap: (i) => onOpen(projects[i]),
    columns: [
      JitanTableColumn(label: t.t(AdminTextKeys.reportColumnProject), flex: _flexPhoneProject),
      JitanTableColumn(label: t.t(AdminTextKeys.reportRegistered), flex: _flexPhoneHours, align: JitanColumnAlign.end),
      const JitanTableColumn(label: '', flex: _flexPhoneOpen, align: JitanColumnAlign.end),
    ],
    rowCount: projects.length,
    cells: (i) => [
      Text(projects[i].project.fullName, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCellStrong),
      Text(ReportText.hours(context, projects[i].workedMinutes), style: JitanTextStyles.tableCell),
      const Align(
        alignment: Alignment.centerRight,
        child: Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
      ),
    ],
  );
}
