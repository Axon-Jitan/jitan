import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../period/period_text.dart';
import '../time_records/time_record_card.dart';
import '../time_records/time_record_popup.dart';
import 'report_employee_dialog.dart';
import 'report_popup_numbers.dart';
import 'report_text.dart';

Future<void> showProjectReportDialog(BuildContext context, {required ProjectReportProject project, required ChosenPeriod period}) =>
    showJitanModal<void>(context, builder: (_) => ProjectReportDialog(project: project, period: period));

/// One project's period (Figma `HR / Reports V2 — a project` `1572:593`):
/// its numbers, then each employee who worked on it or travelled for it, in
/// one card. The same size as an employee's pop-up.
class ProjectReportDialog extends StatelessWidget {
  const ProjectReportDialog({super.key, required this.project, required this.period});

  final ProjectReportProject project;
  final ChosenPeriod period;

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
    return TimeRecordPopup(
      width: ReportEmployeeDialog.width,
      height: ReportEmployeeDialog.height,
      title: project.project.fullName,
      subtitle: _subtitle(context),
      body: [
        ReportPopupNumbers(
          numbers: [
            (context.t(AdminTextKeys.reportRegistered), ReportText.hours(context, project.workedMinutes), null),
            (context.t(AdminTextKeys.reportTravel), ReportText.hours(context, project.travelMinutes), null),
            (
              context.t(AdminTextKeys.reportColumnKilometres),
              ReportText.distance(context, project.trips, project.distanceMetres),
              project.tripsWithoutDistance > 0 ? JitanColors.warning : null,
            ),
          ],
        ),
        const SizedBox(height: 18),
        TimeRecordCard(
          compact: true,
          widths: const [60, 100, 90, 50],
          labelHeading: context.t(AdminTextKeys.reportColumnEmployee),
          headings: [
            context.t(AdminTextKeys.reportColumnDays),
            context.t(AdminTextKeys.reportRegistered),
            context.t(AdminTextKeys.reportTravel),
            context.t(AdminTextKeys.reportColumnTrips),
          ],
          rows: [
            for (final e in project.employees)
              TimeRecordCardRow(
                label: ReportText.person(e.firstName, e.lastName, e.code),
                leading: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: ReportText.person(e.firstName, e.lastName, e.code),
                        style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: '  ${e.code}', style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                values: [
                  Text('${e.days}', style: JitanTextStyles.tableCell),
                  Text(ReportText.hours(context, e.workedMinutes), style: JitanTextStyles.tableCell),
                  Text(ReportText.hoursOrNone(context, e.travelMinutes), style: e.travelMinutes == 0 ? muted : JitanTextStyles.tableCell),
                  Text(e.trips == 0 ? '—' : '${e.trips}', style: e.trips == 0 ? muted : JitanTextStyles.tableCell),
                ],
              ),
          ],
        ),
      ],
      actions: [
        JitanSecondaryButton(label: context.t(AdminTextKeys.reportClose), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
