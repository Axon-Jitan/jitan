import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../period/period_text.dart';
import '../time_records/time_record_card.dart';
import '../time_records/time_record_popup.dart';
import '../time_records/time_record_text.dart';
import 'report_popup_numbers.dart';
import 'report_text.dart';

Future<void> showReportEmployeeDialog(BuildContext context, {required HoursReportEmployee employee, required ChosenPeriod period}) =>
    showJitanModal<void>(context, builder: (_) => ReportEmployeeDialog(employee: employee, period: period));

/// One employee's period (Figma `HR / Reports V2 — an employee` `1572:240`):
/// their numbers, then their days in one card. 640 × 600 for every
/// employee; a long period scrolls inside.
class ReportEmployeeDialog extends StatelessWidget {
  const ReportEmployeeDialog({super.key, required this.employee, required this.period});

  final HoursReportEmployee employee;
  final ChosenPeriod period;

  static const width = 640.0;
  static const height = 600.0;

  Widget _status(BuildContext context, HoursReportDay day) {
    final away = day.awayMinutes > 0 && day.status == TimeRecordStatus.complete;
    if (away) {
      return Text(
        context.t(AdminTextKeys.reportDayAway, args: {'time': ReportText.hours(context, day.awayMinutes)}),
        style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
      );
    }
    return JitanStatusLabel(
      label: TimeRecordText.status(context, day.status),
      isPositive: day.status == TimeRecordStatus.complete,
      color: TimeRecordText.statusColor(day.status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    // A phone keeps the day, what it counts and its status.
    final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
    return TimeRecordPopup(
      width: width,
      height: height,
      title: ReportText.name(employee),
      subtitle: '${PeriodText.range(context, period.from, period.to)} · ${employee.code}',
      body: [
        ReportPopupNumbers(
          numbers: [
            (context.t(AdminTextKeys.reportPlanned), ReportText.hours(context, employee.plannedMinutes), null),
            (context.t(AdminTextKeys.reportRegistered), ReportText.hours(context, employee.registeredMinutes), null),
            (context.t(AdminTextKeys.reportDifference), ReportText.difference(context, employee.differenceMinutes), null),
            if (employee.travelMinutes > 0)
              (context.t(AdminTextKeys.reportTravel), ReportText.hours(context, employee.travelMinutes), null),
          ],
        ),
        const SizedBox(height: 18),
        if (employee.days.isEmpty)
          Text(context.t(AdminTextKeys.reportDaysNone), style: JitanTextStyles.stateMessage)
        else
          TimeRecordCard(
            compact: true,
            widths: phone ? const [64, 108] : const [130, 100, 140],
            labelHeading: context.t(AdminTextKeys.reportColumnDay),
            headings: [
              if (!phone) context.t(AdminTextKeys.reportColumnHours),
              context.t(AdminTextKeys.reportRegistered),
              context.t(AdminTextKeys.reportColumnStatus),
            ],
            rows: [
              for (final day in employee.days)
                TimeRecordCardRow(
                  label: phone ? ReportText.shortDay(context, day.date) : ReportText.day(context, day.date),
                  values: [
                    if (!phone)
                      Text(TimeRecordText.range(day.start, day.finish), style: day.start == null && day.finish == null ? muted : JitanTextStyles.tableCell),
                    Text(
                      day.registeredMinutes == null ? '—' : ReportText.hours(context, day.registeredMinutes!),
                      style: day.registeredMinutes == null ? muted : JitanTextStyles.tableCell,
                    ),
                    _status(context, day),
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
