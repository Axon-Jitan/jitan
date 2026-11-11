import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../period/period_text.dart';
import 'report_text.dart';

Future<void> showProjectReportDialog(BuildContext context, {required ProjectReportProject project, required ChosenPeriod period}) =>
    showJitanModal<void>(context, builder: (_) => ProjectReportDialog(project: project, period: period));

/// One project's period (Figma `1515:190`): its numbers, and each employee who
/// worked on it or travelled for it.
class ProjectReportDialog extends StatelessWidget {
  const ProjectReportDialog({super.key, required this.project, required this.period});

  final ProjectReportProject project;
  final ChosenPeriod period;

  static const _flexEmployee = 210;
  static const _flexDays = 110;
  static const _flexHours = 110;
  static const _flexTravel = 130;
  static const _flexTrips = 150;

  Widget _total(BuildContext context, String labelKey, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.t(labelKey), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
      const SizedBox(height: 2),
      Text(value, style: JitanTextStyles.pageTitle.copyWith(fontSize: 20)),
    ],
  );

  String _subtitle(BuildContext context) {
    final summary = project.project;
    final kind = context.t(summary.isClientSite ? AdminTextKeys.projectPlaceClientOnly : AdminTextKeys.projectPlaceWorkshopOnly);
    return [
      PeriodText.range(context, period.from, period.to),
      kind,
      if (summary.placeName case final place? when place.isNotEmpty) place,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    return JitanModal(
      width: 760,
      title: project.project.fullName,
      subtitle: _subtitle(context),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Wrap(
            spacing: 40,
            runSpacing: 12,
            children: [
              _total(context, AdminTextKeys.reportRegistered, ReportText.hours(context, project.workedMinutes)),
              _total(context, AdminTextKeys.reportTravel, ReportText.hours(context, project.travelMinutes)),
              _total(context, AdminTextKeys.reportColumnKilometres, ReportText.distance(context, project.trips, project.distanceMetres)),
            ],
          ),
          const SizedBox(height: 20),
          JitanDataTable(
            minWidth: 620,
            columns: [
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnEmployee), flex: _flexEmployee),
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnDays), flex: _flexDays),
              JitanTableColumn(label: context.t(AdminTextKeys.reportRegistered), flex: _flexHours),
              JitanTableColumn(label: context.t(AdminTextKeys.reportTravel), flex: _flexTravel),
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnTrips), flex: _flexTrips),
            ],
            rows: [
              for (final e in project.employees)
                [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: ReportText.person(e.firstName, e.lastName, e.code), style: JitanTextStyles.tableCellStrong),
                        TextSpan(text: '  ${e.code}', style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('${e.days}', style: JitanTextStyles.tableCell),
                  Text(ReportText.hours(context, e.workedMinutes), style: JitanTextStyles.tableCell),
                  Text(ReportText.hoursOrNone(context, e.travelMinutes), style: e.travelMinutes == 0 ? muted : JitanTextStyles.tableCell),
                  Text(e.trips == 0 ? '—' : '${e.trips}', style: e.trips == 0 ? muted : JitanTextStyles.tableCell),
                ],
            ],
          ),
        ],
      ),
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.reportClose), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
