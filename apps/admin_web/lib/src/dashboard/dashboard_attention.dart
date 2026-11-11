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
/// (`1470:206`).
class DashboardAttention extends StatelessWidget {
  const DashboardAttention({super.key, required this.dashboard, required this.period, required this.today});

  final Dashboard dashboard;

  /// The Dashboard's period: the days to review are counted in it.
  final ChosenPeriod period;
  final DateTime today;

  /// Time records shows at most this many days at once.
  static const _maxDays = TimeRecordList.maxPeriodDays;

  @override
  Widget build(BuildContext context) {
    DateTime date(DateTime d) => DateTime(d.year, d.month, d.day);
    DateTime back(DateTime d, int days) => DateTime(d.year, d.month, d.day - days);
    final to = date(period.to);
    // A longer period opens its last 62 days.
    final from = date(period.from).isBefore(back(to, _maxDays - 1)) ? back(to, _maxDays - 1) : date(period.from);
    final rows = [
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
    ].where((row) => row.$2 > 0).toList();
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
          for (final (i, (key, count, path)) in rows.indexed) ...[
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
                      Text(DashboardText.number(count), style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.warning)),
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
