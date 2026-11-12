import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'report_numbers_card.dart';
import 'report_text.dart';

/// The employees' month in numbers (Figma `1571:2`). Travel sits next to
/// Worked and is never part of it. Days to review, when there are any, open
/// them in Time records ([onReview]).
class ReportTotalsCard extends StatelessWidget {
  const ReportTotalsCard({super.key, required this.employees, required this.onReview});

  final List<HoursReportEmployee> employees;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    int sum(int Function(HoursReportEmployee) of) => employees.fold(0, (total, e) => total + of(e));
    final planned = sum((e) => e.plannedMinutes);
    final registered = sum((e) => e.registeredMinutes);
    final travel = sum((e) => e.travelMinutes);
    final toReview = sum((e) => e.daysToReview);
    return ReportNumbersCard(
      numbers: [
        (context.t(AdminTextKeys.reportPlanned), ReportText.hours(context, planned), JitanColors.ink, null),
        (context.t(AdminTextKeys.reportRegistered), ReportText.hours(context, registered), JitanColors.ink, null),
        (context.t(AdminTextKeys.reportDifference), ReportText.difference(context, registered - planned), JitanColors.ink, null),
        (context.t(AdminTextKeys.reportTravel), ReportText.hours(context, travel), JitanColors.ink, null),
        (
          context.t(AdminTextKeys.reportToReview),
          '$toReview',
          toReview > 0 ? JitanColors.warning : JitanColors.ink,
          toReview > 0 ? onReview : null,
        ),
      ],
    );
  }
}
