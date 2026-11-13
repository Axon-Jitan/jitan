import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../home/home_hero.dart';
import '../home/home_page.dart';
import '../home/home_text.dart';
import '../l10n/employee_text_keys.dart';
import '../today/today_controller.dart';
import '../today/today_text.dart';
import 'day_details_screen.dart';
import 'period_controller.dart';
import 'period_stamps.dart';
import 'period_text.dart';
import 'period_widgets.dart';

/// "Period" (Figma `1595:577`, 2026-11-13): the employee's own registered
/// time, from the server, in Home's calm style: a Day | Week | Month switch,
/// the total card and the day's timeline with its stamps (registrations,
/// what the day went on, the break).
class PeriodScreen extends StatefulWidget {
  const PeriodScreen({
    super.key,
    required this.api,
    required this.onSessionEnded,
    this.clock,
    this.bottomBar,
    this.current,
    this.activities = const [],
    this.initialView = PeriodView.day,
  });

  final TimeRegistrationsApi api;
  final VoidCallback onSessionEnded;
  final DateTime Function()? clock;
  final Widget? bottomBar;

  /// What the employee is on, so the total here is the one on Home (D39).
  final CurrentActivity? current;

  /// Today's activities, as Home already has them.
  final List<ActivityEntry> activities;

  /// Week when opened from Home's "This week".
  final PeriodView initialView;

  @override
  State<PeriodScreen> createState() => _PeriodScreenState();
}

class _PeriodScreenState extends State<PeriodScreen> {
  late final _controller = PeriodController(
    widget.api,
    onSessionEnded: widget.onSessionEnded,
    clock: widget.clock,
    view: widget.initialView,
  )..load();

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
          now: _controller.now,
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
      final navBar = widget.bottomBar ?? const SizedBox.shrink();
      if (_controller.state is PeriodFailed) {
        return HomePage(
          navBar: navBar,
          onRefresh: _controller.load,
          title: context.t(EmployeeTextKeys.periodFailedTitle),
          subtitle: context.t(EmployeeTextKeys.todayCheckConnection),
          action: JitanMobileButton(
            label: context.t(EmployeeTextKeys.todayTryAgain),
            size: JitanMobileButtonSize.phone,
            onPressed: _controller.load,
          ),
        );
      }
      final (from, to) = _controller.range;
      return HomePage(
        navBar: navBar,
        onRefresh: _controller.load,
        title: context.t(EmployeeTextKeys.periodTitle),
        subtitle: switch (_controller.view) {
          PeriodView.day => PeriodText.dayMonth(context, from),
          PeriodView.week => PeriodText.range(context, from, to),
          PeriodView.month => PeriodText.month(context, from),
        },
        children: [
          PeriodViewSwitch(view: _controller.view, onSelected: _controller.select),
          const SizedBox(height: 16),
          ...switch (_controller.state) {
            PeriodDayLoaded(:final today) => _day(context, today),
            PeriodRangeLoaded(:final period) => _controller.view == PeriodView.week ? _week(context, period) : _month(context, period),
            _ => const [PeriodSkeleton()],
          },
        ],
      );
    },
  );

  /// This day: Home's total card and today's timeline.
  List<Widget> _day(BuildContext context, MyDay today) {
    final day = today.day;
    final start =
        day?.start?.rounded ??
        day?.start?.actual ??
        switch (day?.pending.where((p) => p.boundary == RegistrationBoundary.start).firstOrNull) {
          final p? => p.rounded ?? p.requested,
          null => null,
        };
    // Running exactly when Home says so, a start waiting for HR included
    // (D39: the total here is the one on Home).
    final working = TodayController.phaseOf(today) == TodayPhase.working;
    final now = _controller.now();
    final minutes =
        today.registeredMinutes ??
        (day == null ? 0 : null) ??
        (working && start != null ? RunningTotal.ofToday(today, start, widget.current, now) : null);
    final line = working
        ? context.t(EmployeeTextKeys.periodWorkingSince, args: {'time': shownTime(day, RegistrationBoundary.start).local ?? '--:--'})
        : today.registeredMinutes != null
        ? HomeText.plannedLine(context, today)
        : day == null
        ? null
        : PeriodText.dayLine(context, MyPeriodDay(date: today.date, day: day)).$1;
    final stamps = PeriodStamps.of(
      context,
      day: day,
      activities: widget.activities,
      breakStart: today.breakStart,
      breakMinutes: today.breakMinutes,
      now: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
    return [
      HomeHero(
        label: context.t(EmployeeTextKeys.todayWorkingRegistered),
        value: minutes == null ? context.t(EmployeeTextKeys.periodNotCounted) : TodayText.duration(context, minutes),
        smallValue: minutes == null,
        dark: working,
        lines: [?line],
      ),
      const SizedBox(height: 24),
      if (stamps.isEmpty)
        Text(context.t(EmployeeTextKeys.periodNothingToday), style: JitanMobileTextStyles.pageSubtitle)
      else
        PeriodTimeline(stamps: stamps),
    ];
  }

  /// This week: the total, a bar per day and the days.
  List<Widget> _week(BuildContext context, MyPeriod period) => [
    HomeHero(
      label: context.t(EmployeeTextKeys.periodWeekRegistered),
      value: PeriodText.duration(context, period.registeredMinutes),
      lines: [
        if (period.plannedMinutes > 0)
          context.t(EmployeeTextKeys.periodWeekPlanned, args: {'hours': PeriodText.hours(context, period.plannedMinutes)}),
      ],
    ),
    const SizedBox(height: 12),
    PeriodWeekChart(days: period.days, today: _controller.today),
    const SizedBox(height: 12),
    PeriodDayList(
      days: [
        for (final d in period.days)
          if (!d.date.isAfter(_controller.today)) d,
      ],
      onOpen: (d) => _open(d.date),
    ),
  ];

  /// This month: registered and planned, and the calendar.
  List<Widget> _month(BuildContext context, MyPeriod period) => [
    PeriodPairCard(
      items: [
        (context.t(EmployeeTextKeys.periodMonthRegistered), PeriodText.duration(context, period.registeredMinutes)),
        (context.t(EmployeeTextKeys.periodMonthPlanned), PeriodText.hours(context, period.plannedMinutes)),
      ],
    ),
    const SizedBox(height: 12),
    PeriodMonthCalendar(
      days: period.days,
      today: _controller.today,
      onOpen: (d) {
        if (!d.date.isAfter(_controller.today)) _open(d.date);
      },
    ),
    const SizedBox(height: 12),
    const PeriodLegend(),
  ];
}
