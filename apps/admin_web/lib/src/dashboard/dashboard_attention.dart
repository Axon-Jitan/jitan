import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../app/admin_routes.dart';
import '../l10n/admin_text_keys.dart';
import '../period/chosen_period.dart';
import '../time_records/time_record_status_filter.dart';
import 'dashboard_card.dart';
import 'dashboard_text.dart';

/// What HR can act on, each row opening the page to do it, already showing
/// what was counted (Figma `1470:2`); one calm line when there is nothing
/// (`1470:206`). When Jitan could not complete its own lists, one more row
/// says so and opens them (`1577:2`).
class DashboardAttention extends StatelessWidget {
  const DashboardAttention({super.key, required this.dashboard, required this.period, required this.today});

  final Dashboard dashboard;

  /// The Dashboard's period: the days to review are counted in it.
  final ChosenPeriod period;
  final DateTime today;

  /// Time records shows at most this many days at once.
  static const _maxDays = TimeRecordList.maxPeriodDays;

  /// The days to review of [period] in Time records: a longer period opens
  /// its last 62 days.
  static (DateTime, DateTime) reviewDays(ChosenPeriod period) {
    final to = DateTime(period.to.year, period.to.month, period.to.day);
    final earliest = DateTime(to.year, to.month, to.day - (_maxDays - 1));
    final from = DateTime(period.from.year, period.from.month, period.from.day);
    return (from.isBefore(earliest) ? earliest : from, to);
  }

  @override
  Widget build(BuildContext context) {
    DateTime date(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime back(DateTime d, int days) => DateTime(d.year, d.month, d.day - days);
    final (from, to) = reviewDays(period);
    final counted = [
      (
        AdminTextKeys.dashboardCorrections,
        dashboard.correctionsWaiting,
        // The server counts the corrections of the last 62 days.
        AdminRoutes.timeRecordsOf(
          status: TimeRecordStatus.pendingReview.wireName,
          from: back(date(today), _maxDays - 1),
          to: date(today),
        ),
      ),
      (
        AdminTextKeys.dashboardDaysToReview,
        dashboard.toReview,
        AdminRoutes.timeRecordsOf(status: TimeRecordStatusFilter.toReview.wireName, from: from, to: to),
      ),
      (AdminTextKeys.dashboardNotSetUp, dashboard.employeesNotSetUp, AdminRoutes.employeesNotSetUp),
    ].where((row) => row.$2 > 0);
    final warning = JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.warning);
    final rows = [
      for (final (key, count, path) in counted) (key, DashboardText.number(count), warning, path),
      if (!dashboard.setupFinished)
        (
          AdminTextKeys.dashboardSetupNotFinished,
          context.t(AdminTextKeys.dashboardSetupAskIt),
          JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
          AdminRoutes.lists,
        ),
    ];
    if (rows.isEmpty) {
      return DashboardCard(
        title: context.t(AdminTextKeys.dashboardClearTitle),
        note: context.t(AdminTextKeys.dashboardClearText),
        child: const SizedBox.shrink(),
      );
    }
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 10),
            child: Semantics(
              header: true,
              child: Text(context.t(AdminTextKeys.dashboardAttention), style: DashboardCard.titleStyle),
            ),
          ),
          for (final (i, (key, value, valueStyle, path)) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, color: JitanColors.inputBorder),
            InkWell(
              hoverColor: JitanColors.tableHover,
              onTap: () => context.go(path),
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.t(key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JitanTextStyles.tableCell.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(value, style: valueStyle),
                      const SizedBox(width: 14),
                      const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
