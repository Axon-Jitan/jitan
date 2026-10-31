import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../auth/platform/session_store.dart';
import '../groups/group_state_text.dart';
import '../l10n/admin_text_keys.dart';
import 'dashboard_attention.dart';
import 'dashboard_card.dart';
import 'dashboard_company_bars.dart';
import 'dashboard_controller.dart';
import 'dashboard_donut.dart';
import 'dashboard_hours_chart.dart';
import 'dashboard_period_button.dart';
import 'dashboard_text.dart';
import 'dashboard_tiles.dart';

/// HR/Admin Dashboard (Figma `1470:2`, nothing to do `1470:206`, period picker
/// `1475:16`, phone `1476:4`): only what Jitan can calculate, and every number
/// from the server. Today and the totals are always now; hours, attendance and
/// days to review follow the period.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api, required this.store, this.today});

  final DashboardApi api;
  final SessionStore store;

  /// `DateTime.now` when `null`.
  final DateTime Function()? today;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final _now = (widget.today ?? DateTime.now)();
  late final _controller = DashboardController(widget.api, widget.store, today: _now)..load();

  static const _gap = 20.0;

  /// From these widths two cards sit side by side.
  static const _chartsAcrossFrom = 1000.0;
  static const _pairAcrossFrom = 840.0;

  /// Side by side, both cards take the height of the taller one.
  static const _chartsHeight = 300.0;
  static const _pairMinHeight = 284.0;
  static const _companyCardChrome = 108.0;
  static const _companyRowHeight = 34.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => JitanListPage(
    top: ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final phone = MediaQuery.sizeOf(context).width < JitanDimensions.phoneBreakpoint;
        return Padding(
          padding: const EdgeInsets.only(bottom: _gap),
          child: JitanPageHeader(
            title: context.t(AdminTextKeys.dashboardTitle),
            subtitle: DashboardText.longDate(context, _now),
            action: DashboardPeriodButton(
              period: _controller.period,
              today: _now,
              onChanged: _controller.updatePeriod,
              expanded: phone,
            ),
          ),
        );
      },
    ),
    list: [
      ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => SliverToBoxAdapter(
          child: switch (_controller.state) {
            DashboardLoading() => GroupStateText(context.t(AdminTextKeys.dashboardLoading)),
            DashboardFailed() => GroupStateText(context.t(AdminTextKeys.dashboardLoadFailed), onRetry: _controller.load),
            DashboardLoaded(:final dashboard) => _content(context, dashboard),
          },
        ),
      ),
    ],
  );

  Widget _content(BuildContext context, Dashboard dashboard) => LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: _gap,
      children: [
        DashboardTiles(dashboard: dashboard),
        _pair(
          across: constraints.maxWidth >= _chartsAcrossFrom,
          height: _chartsHeight,
          flex: (440, 676),
          first: _today(context, dashboard),
          second: _hours(context, dashboard),
        ),
        _pair(
          across: constraints.maxWidth >= _pairAcrossFrom,
          height: math.max(_pairMinHeight, _companyCardChrome + dashboard.companies.length * _companyRowHeight),
          first: _companies(context, dashboard),
          second: _attendance(context, dashboard),
        ),
        DashboardAttention(dashboard: dashboard),
      ],
    ),
  );

  Widget _pair({
    required bool across,
    required double height,
    required Widget first,
    required Widget second,
    (int, int) flex = (1, 1),
  }) => across
      ? SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: [
              Expanded(flex: flex.$1, child: first),
              Expanded(flex: flex.$2, child: second),
            ],
          ),
        )
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: _gap, children: [first, second]);

  Widget _today(BuildContext context, Dashboard dashboard) => DashboardCard(
    title: context.t(AdminTextKeys.dashboardToday),
    note: context.t(AdminTextKeys.dashboardTodayNote),
    child: DashboardDonut(
      centre: DashboardText.number(dashboard.working + dashboard.finished + dashboard.notStarted),
      caption: context.t(AdminTextKeys.dashboardScheduled),
      parts: [
        (label: context.t(AdminTextKeys.dashboardWorking), value: dashboard.working, color: JitanColors.chartGreen),
        (label: context.t(AdminTextKeys.dashboardFinished), value: dashboard.finished, color: JitanColors.chartViolet),
        (label: context.t(AdminTextKeys.dashboardNotStarted), value: dashboard.notStarted, color: JitanColors.chartAmber),
      ],
    ),
  );

  Widget _hours(BuildContext context, Dashboard dashboard) => DashboardCard(
    title: context.t(AdminTextKeys.dashboardHours),
    note: context.t(switch (dashboard.bucketSize) {
      DashboardBucketSize.day => AdminTextKeys.dashboardHoursDay,
      DashboardBucketSize.week => AdminTextKeys.dashboardHoursWeek,
      DashboardBucketSize.month => AdminTextKeys.dashboardHoursMonth,
    }),
    trailing: const DashboardHoursLegend(),
    child: DashboardHoursChart(buckets: dashboard.buckets, size: dashboard.bucketSize),
  );

  Widget _companies(BuildContext context, Dashboard dashboard) => DashboardCard(
    title: context.t(AdminTextKeys.dashboardByCompany),
    note: context.t(AdminTextKeys.dashboardByCompanyNote),
    child: DashboardCompanyBars(companies: dashboard.companies),
  );

  Widget _attendance(BuildContext context, Dashboard dashboard) {
    final total = dashboard.onTime + dashboard.late + dashboard.leftEarly + dashboard.toReview;
    return DashboardCard(
      title: context.t(AdminTextKeys.dashboardAttendance),
      note: context.t(AdminTextKeys.dashboardAttendanceNote),
      child: DashboardDonut(
        centre: total == 0
            ? '–'
            : context.t(AdminTextKeys.dashboardPercent, args: {'percent': (dashboard.onTime / total * 100).round()}),
        caption: context.t(AdminTextKeys.dashboardOnTimeCaption),
        parts: [
          (label: context.t(AdminTextKeys.dashboardOnTime), value: dashboard.onTime, color: JitanColors.chartGreen),
          (label: context.t(AdminTextKeys.dashboardLate), value: dashboard.late, color: JitanColors.chartAmber),
          (label: context.t(AdminTextKeys.dashboardLeftEarly), value: dashboard.leftEarly, color: JitanColors.chartViolet),
          (label: context.t(AdminTextKeys.dashboardToReview), value: dashboard.toReview, color: JitanColors.chartBlue),
        ],
      ),
    );
  }
}
