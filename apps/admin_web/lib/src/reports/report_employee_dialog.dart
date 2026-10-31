import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../time_records/time_record_text.dart';
import 'report_text.dart';

Future<void> showReportEmployeeDialog(BuildContext context, {required HoursReportEmployee employee, required String month}) =>
    showJitanModal<void>(context, builder: (_) => ReportEmployeeDialog(employee: employee, month: month));

/// One employee's month (Figma `1467:391`): their numbers and their days.
class ReportEmployeeDialog extends StatelessWidget {
  const ReportEmployeeDialog({super.key, required this.employee, required this.month});

  final HoursReportEmployee employee;
  final String month;

  static const _flexDay = 210;
  static const _flexTime = 110;
  static const _flexRegistered = 130;
  static const _flexStatus = 150;

  Widget _total(BuildContext context, String labelKey, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(context.t(labelKey), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
      const SizedBox(height: 2),
      Text(value, style: JitanTextStyles.pageTitle.copyWith(fontSize: 20)),
    ],
  );

  Widget _status(BuildContext context, HoursReportDay day) {
    final away = day.awayMinutes > 0 && day.status == TimeRecordStatus.complete;
    return Text(
      away
          ? context.t(AdminTextKeys.reportDayAway, args: {'time': ReportText.hours(context, day.awayMinutes)})
          : TimeRecordText.status(context, day.status),
      style: JitanTextStyles.tableCell.copyWith(
        fontWeight: FontWeight.w500,
        color: away ? JitanColors.inkMuted : TimeRecordText.statusColor(day.status),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => JitanModal(
    width: 760,
    title: ReportText.name(employee),
    subtitle: '${ReportText.month(context, month)} · ${employee.code}',
    onClose: () => Navigator.of(context).pop(),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 40,
          runSpacing: 12,
          children: [
            _total(context, AdminTextKeys.reportPlanned, ReportText.hours(context, employee.plannedMinutes)),
            _total(context, AdminTextKeys.reportRegistered, ReportText.hours(context, employee.registeredMinutes)),
            _total(context, AdminTextKeys.reportDifference, ReportText.difference(context, employee.differenceMinutes)),
          ],
        ),
        const SizedBox(height: 20),
        if (employee.days.isEmpty)
          Text(context.t(AdminTextKeys.reportDaysNone), style: JitanTextStyles.stateMessage)
        else
          JitanDataTable(
            minWidth: 620,
            columns: [
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnDay), flex: _flexDay),
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnStart), flex: _flexTime),
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnFinish), flex: _flexTime),
              JitanTableColumn(label: context.t(AdminTextKeys.reportRegistered), flex: _flexRegistered),
              JitanTableColumn(label: context.t(AdminTextKeys.reportColumnStatus), flex: _flexStatus),
            ],
            rows: [
              for (final day in employee.days)
                [
                  Text(ReportText.day(context, day.date), style: JitanTextStyles.tableCellStrong),
                  Text(day.start ?? '—', style: JitanTextStyles.tableCell),
                  Text(day.finish ?? '—', style: JitanTextStyles.tableCell),
                  Text(
                    day.registeredMinutes == null ? '—' : ReportText.hours(context, day.registeredMinutes!),
                    style: JitanTextStyles.tableCell,
                  ),
                  _status(context, day),
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
