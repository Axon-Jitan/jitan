import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_text.dart';
import '../widgets/mobile_widgets.dart';
import 'day_details_screen.dart';
import 'period_controller.dart';
import 'period_text.dart';
import 'period_widgets.dart';

/// "Period" (Figma 35:57 this day, 48:2 week, 48:49 month, menu 398:6): the
/// employee's own registered time, from the server.
///
/// Different from Figma, on purpose: the timeline holds registrations and
/// corrections only (leaving and returning to a workplace needs geofencing,
/// phase 4), and "Weekly breakdown" / "Daily breakdown" are left out (they
/// split time by project, which waits for IT's ERD update).
class PeriodScreen extends StatefulWidget {
  const PeriodScreen({super.key, required this.api, required this.onSessionEnded, this.clock, this.bottomBar});

  final TimeRegistrationsApi api;
  final VoidCallback onSessionEnded;
  final DateTime Function()? clock;
  final Widget? bottomBar;

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends State<PeriodScreen> {
  late final _controller = PeriodController(widget.api, onSessionEnded: widget.onSessionEnded, clock: widget.clock)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(DateTime date) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DayDetailsScreen(
          api: widget.api,
          date: date,
          today: _controller.today,
          onSessionEnded: widget.onSessionEnded,
          bottomBar: widget.bottomBar,
        ),
      ),
    );
    if (changed == true && mounted) await _controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final (from, to) = _controller.range;
      final subtitle = switch (_controller.view) {
        PeriodView.day => PeriodText.dayMonth(context, from),
        PeriodView.week => PeriodText.range(context, from, to),
        PeriodView.month => PeriodText.month(context, from),
      };
      return Scaffold(
        backgroundColor: JitanColors.warmWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: RefreshIndicator(
                    color: JitanColors.ink,
                    onRefresh: _controller.load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(alignment: Alignment.centerLeft, child: JitanWordmark()),
                          const SizedBox(height: 40),
                          Semantics(header: true, child: Text(context.t(EmployeeTextKeys.periodTitle), style: JitanMobileTextStyles.title)),
                          const SizedBox(height: 6),
                          Text(subtitle, style: JitanMobileTextStyles.body),
                          const SizedBox(height: 22),
                          PeriodViewSelector(view: _controller.view, onSelected: _controller.select),
                          const SizedBox(height: 16),
                          ..._content(context),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.bottomBar case final bar?) ...[const SizedBox(height: 16), bar],
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _content(BuildContext context) => switch (_controller.state) {
    PeriodLoading() => const [
      Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: JitanColors.ink, strokeWidth: 2))),
    ],
    PeriodFailed() => [
      const SizedBox(height: 40),
      Text(context.t(EmployeeTextKeys.periodLoadFailed), style: JitanMobileTextStyles.cardTitle),
      const SizedBox(height: 6),
      Text(context.t(EmployeeTextKeys.todayCheckConnection), style: JitanMobileTextStyles.body),
      const SizedBox(height: 16),
      JitanMobileButton(label: context.t(EmployeeTextKeys.todayTryAgain), onPressed: _controller.load),
    ],
    PeriodDayLoaded(:final today) => _day(context, today),
    PeriodRangeLoaded(:final period) => _controller.view == PeriodView.week ? _week(context, period) : _month(context, period),
  };

  /// This day (35:57): registered so far and today's timeline.
  List<Widget> _day(BuildContext context, MyDay today) {
    final day = today.day;
    final start = day?.start?.rounded ?? day?.start?.actual ?? day?.pending.where((p) => p.boundary == RegistrationBoundary.start).firstOrNull?.requested;
    final open = day != null && day.finish == null && day.status != TimeRecordStatus.nonWork;
    final minutes = today.registeredMinutes ??
        (day == null ? 0 : null) ??
        (open && start != null
            ? RunningTotal.minutes(start: start, now: _controller.now(), breakStart: today.breakStart, breakFinish: today.breakFinish)
            : null);
    return [
      PeriodTotalCard(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(minutes == null ? '—' : TodayText.duration(context, minutes), style: PeriodTotalCard.big()),
                    const SizedBox(height: 4),
                    Text(context.t(EmployeeTextKeys.periodSoFar), style: PeriodTotalCard.small()),
                  ],
                ),
              ),
              if (day != null) PeriodBadge(label: PeriodText.status(context, day.status), color: PeriodText.statusColor(day.status)),
            ],
          ),
        ],
      ),
      const SizedBox(height: 26),
      Text(context.t(EmployeeTextKeys.periodTimelineToday), style: JitanMobileTextStyles.fieldLabel),
      const SizedBox(height: 16),
      if (day == null || day.events.isEmpty)
        Text(context.t(EmployeeTextKeys.periodNothingToday), style: JitanMobileTextStyles.body)
      else
        PeriodTimeline(events: day.events, pending: day.pending),
    ];
  }

  /// This week (48:2): the total, a bar per day and the daily records.
  List<Widget> _week(BuildContext context, MyPeriod period) => [
    PeriodTotalCard(
      children: [
        Text(context.t(EmployeeTextKeys.periodWeekTotal), style: PeriodTotalCard.small().copyWith(fontWeight: FontWeight.w600, fontSize: 10)),
        const SizedBox(height: 8),
        Text(PeriodText.hours(context, period.registeredMinutes), style: PeriodTotalCard.big()),
      ],
    ),
    const SizedBox(height: 24),
    Text(context.t(EmployeeTextKeys.periodWeekChart), style: JitanMobileTextStyles.cardTitle),
    const SizedBox(height: 12),
    PeriodWeekChart(days: period.days),
    const SizedBox(height: 24),
    Text(context.t(EmployeeTextKeys.periodWeekRecords), style: JitanMobileTextStyles.cardTitle),
    const SizedBox(height: 12),
    PeriodDayList(days: [for (final d in period.days) if (!d.date.isAfter(_controller.today)) d], onOpen: (d) => _open(d.date)),
  ];

  /// This month (48:49): planned and registered, the calendar and its legend.
  List<Widget> _month(BuildContext context, MyPeriod period) => [
    PeriodTotalCard(
      children: [
        Row(
          children: [
            for (final (key, minutes) in [
              (EmployeeTextKeys.periodMonthPlanned, period.plannedMinutes),
              (EmployeeTextKeys.periodMonthRegistered, period.registeredMinutes),
            ])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(PeriodText.hours(context, minutes), style: PeriodTotalCard.big()),
                    const SizedBox(height: 4),
                    Text(context.t(key), style: PeriodTotalCard.small()),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
    const SizedBox(height: 16),
    PeriodMonthCalendar(
      days: period.days,
      today: _controller.today,
      onOpen: (d) {
        if (!d.date.isAfter(_controller.today)) _open(d.date);
      },
    ),
    const SizedBox(height: 14),
    const PeriodLegend(),
  ];
}
