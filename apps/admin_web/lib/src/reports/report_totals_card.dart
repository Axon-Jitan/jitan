import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'report_text.dart';

/// One quiet card with the month's four numbers (Figma `1467:2`, phone
/// `1482:2`).
class ReportTotalsCard extends StatelessWidget {
  const ReportTotalsCard({super.key, required this.employees});

  final List<HoursReportEmployee> employees;

  @override
  Widget build(BuildContext context) {
    int sum(int Function(HoursReportEmployee) of) => employees.fold(0, (total, e) => total + of(e));
    final planned = sum((e) => e.plannedMinutes);
    final registered = sum((e) => e.registeredMinutes);
    final toReview = sum((e) => e.daysToReview);
    final items = [
      (AdminTextKeys.reportPlanned, ReportText.hours(context, planned), JitanColors.ink),
      (AdminTextKeys.reportRegistered, ReportText.hours(context, registered), JitanColors.ink),
      (AdminTextKeys.reportDifference, ReportText.difference(context, registered - planned), JitanColors.ink),
      (AdminTextKeys.reportToReview, '$toReview', toReview > 0 ? JitanColors.warning : JitanColors.ink),
    ];
    Widget item((String, String, Color) value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(value.$1), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value.$2, style: JitanTextStyles.pageTitle.copyWith(fontSize: 26, color: value.$3)),
        ],
      ),
    );
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    for (final pair in [items.sublist(0, 2), items.sublist(2)])
                      Row(children: [for (final value in pair) Expanded(child: item(value))]),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    children: [
                      for (final (i, value) in items.indexed) ...[
                        if (i > 0) const VerticalDivider(width: 1, color: JitanColors.inputBorder),
                        Expanded(child: item(value)),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
