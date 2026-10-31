import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'report_text.dart';

/// One row per employee (Figma `1467:2`): a row opens their month. On a phone
/// (`1482:2`) only the name, the registered hours and a dot for days to review.
class ReportsTable extends StatelessWidget {
  const ReportsTable({super.key, required this.employees, required this.onOpen});

  final List<HoursReportEmployee> employees;
  final ValueChanged<HoursReportEmployee> onOpen;

  /// Column widths proportional to Figma.
  static const _flexEmployee = 400;
  static const _flexHours = 150;
  static const _flexReview = 150;
  static const _flexOpen = 40;
  static const _flexPhoneEmployee = 200;
  static const _flexPhoneHours = 90;
  static const _flexPhoneOpen = 44;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    if (MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint) return _phone(context, t);
    return JitanSliverTable(
      onRowTap: (i) => onOpen(employees[i]),
      columns: [
        JitanTableColumn(label: t.t(AdminTextKeys.reportColumnEmployee), flex: _flexEmployee),
        JitanTableColumn(label: t.t(AdminTextKeys.reportPlanned), flex: _flexHours),
        JitanTableColumn(label: t.t(AdminTextKeys.reportRegistered), flex: _flexHours),
        JitanTableColumn(label: t.t(AdminTextKeys.reportDifference), flex: _flexHours),
        JitanTableColumn(label: t.t(AdminTextKeys.reportColumnToReview), flex: _flexReview),
        const JitanTableColumn(label: '', flex: _flexOpen, align: JitanColumnAlign.end),
      ],
      rowCount: employees.length,
      cells: (i) {
        final e = employees[i];
        return [
          _name(e),
          Text(ReportText.hours(context, e.plannedMinutes), style: JitanTextStyles.tableCell),
          Text(ReportText.hours(context, e.registeredMinutes), style: JitanTextStyles.tableCellStrong),
          Text(ReportText.difference(context, e.differenceMinutes), style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
          e.daysToReview == 0
              ? Text('—', style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted))
              : Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: JitanColors.warning, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tPlural(AdminTextKeys.reportDays, e.daysToReview),
                        overflow: TextOverflow.ellipsis,
                        style: JitanTextStyles.tableCell.copyWith(color: JitanColors.warning),
                      ),
                    ),
                  ],
                ),
          const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
        ];
      },
      footer: _footer(context),
    );
  }

  Widget _name(HoursReportEmployee e) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: ReportText.name(e), style: JitanTextStyles.tableCellStrong),
        TextSpan(text: '  ${e.code}', style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
      ],
    ),
    overflow: TextOverflow.ellipsis,
  );

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      context.tPlural(AdminTextKeys.reportEmployees, employees.length),
      style: JitanTextStyles.stateMessage.copyWith(fontSize: 12),
    ),
  );

  Widget _phone(BuildContext context, Translations t) => JitanSliverTable(
    minWidth: 0,
    onRowTap: (i) => onOpen(employees[i]),
    columns: [
      JitanTableColumn(label: t.t(AdminTextKeys.reportColumnEmployee), flex: _flexPhoneEmployee),
      JitanTableColumn(label: t.t(AdminTextKeys.reportRegistered), flex: _flexPhoneHours, align: JitanColumnAlign.end),
      const JitanTableColumn(label: '', flex: _flexPhoneOpen, align: JitanColumnAlign.end),
    ],
    rowCount: employees.length,
    cells: (i) {
      final e = employees[i];
      return [
        _name(e),
        Text(ReportText.hours(context, e.registeredMinutes), style: JitanTextStyles.tableCell),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (e.daysToReview > 0)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: JitanColors.warning, shape: BoxShape.circle),
              ),
            const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
          ],
        ),
      ];
    },
    footer: _footer(context),
  );
}
