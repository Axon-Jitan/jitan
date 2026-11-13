import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../home/home_hero.dart';
import '../l10n/employee_text_keys.dart';
import '../widgets/phone_widgets.dart';
import 'missing_time_screen.dart';
import 'period_stamps.dart';
import 'period_text.dart';
import 'period_widgets.dart';

/// One day (Figma `1595:362`, `1595:419`, `1595:504`, 2026-11-13): the
/// date between plain arrows to the previous and next day (a swipe on the
/// day does the same, as in Apple Health), the line under it,
/// the total and the timeline with its stamps. A day with a missing start
/// or finish offers to add it.
class DayDetailsScreen extends StatefulWidget {
  const DayDetailsScreen({
    super.key,
    required this.api,
    required this.date,
    required this.today,
    required this.now,
    required this.onSessionEnded,
    this.bottomBar,
  });

  final TimeRegistrationsApi api;
  final DateTime date;

  /// No stepping past today.
  final DateTime today;
  final DateTime Function() now;
  final VoidCallback onSessionEnded;
  final Widget? bottomBar;

  @override
  State<DayDetailsScreen> createState() => _DayDetailsScreenState();
}

class _DayDetailsScreenState extends State<DayDetailsScreen> {
  late DateTime _date = widget.date;
  MyPeriodDay? _day;
  ApiClientException? _failure;
  bool _loading = true;

  /// Something changed (a time added): the Period list reloads.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final period = await widget.api.period(from: _date, to: _date);
      if (mounted) {
        setState(() {
          _day = period.days.firstOrNull;
          _loading = false;
        });
      }
    } on ApiClientException catch (e) {
      if (e.statusCode == 401) return widget.onSessionEnded();
      if (mounted) {
        setState(() {
          _failure = e;
          _loading = false;
        });
      }
    }
  }

  /// Never past today.
  bool get _canGoForward => !_loading && _date.isBefore(widget.today);

  void _step(int days) {
    _date = DateTime.utc(_date.year, _date.month, _date.day + days);
    _load();
  }

  Future<void> _fix(MyPeriodDay day) async {
    if (await openMissingTime(context, api: widget.api, day: day) && mounted) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final fix = !_loading && _failure == null && day != null && canFixMissing(day);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: JitanColors.warmWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                      onPressed: () => Navigator.of(context).pop(_changed),
                      icon: const PhoneBackIcon(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _dateRow(context),
                Expanded(
                  // Swipe left for the next day, right for the previous one.
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      final speed = details.primaryVelocity ?? 0;
                      if (speed.abs() < 300) return;
                      if (speed < 0 && _canGoForward) _step(1);
                      if (speed > 0 && !_loading) _step(-1);
                    },
                    child: SingleChildScrollView(child: _content(context)),
                  ),
                ),
                if (!_loading && _failure != null) ...[
                  JitanMobileButton(label: context.t(EmployeeTextKeys.todayTryAgain), size: JitanMobileButtonSize.phone, onPressed: _load),
                  const SizedBox(height: 12),
                ],
                if (fix) ...[
                  JitanMobileButton(label: missingTimeAction(context, day), size: JitanMobileButtonSize.phone, onPressed: () => _fix(day)),
                  const SizedBox(height: 12),
                ],
                ?widget.bottomBar,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ‹ Tuesday 20 October ›
  Widget _dateRow(BuildContext context) {
    // Plain chevrons, as Apple Health; a swipe on the day does the same.
    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Icon(icon, size: 26, color: onPressed == null ? JitanColors.radioBorder : JitanColors.ink),
    );
    return Row(
      spacing: 4,
      children: [
        arrow(Icons.chevron_left, context.t(EmployeeTextKeys.periodDayPrevious), _loading ? null : () => _step(-1)),
        Expanded(
          child: Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(PeriodText.dayMonth(context, _date), maxLines: 1, style: JitanMobileTextStyles.pageTitle.copyWith(fontSize: 22, letterSpacing: -0.4)),
            ),
          ),
        ),
        arrow(Icons.chevron_right, context.t(EmployeeTextKeys.periodDayNext), _canGoForward ? () => _step(1) : null),
      ],
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.only(top: 26), child: PeriodSkeleton());
    if (_failure != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The date stays, so another day is one swipe away; Try again
            // sits at the bottom, as on Home and Period (Figma `1608:2`).
            Text(context.t(EmployeeTextKeys.periodDayFailed), textAlign: TextAlign.center, style: JitanMobileTextStyles.pageSubtitle),
          ],
        ),
      );
    }
    final day = _day;
    final record = day?.day;
    final (line, needsYou) = day == null ? (context.t(EmployeeTextKeys.periodNothing), false) : PeriodText.dayLine(context, day);
    final nothing = day == null || (record == null && day.plannedMinutes == null);
    final now = widget.now();
    final stamps = day == null
        ? const <PeriodStamp>[]
        : PeriodStamps.of(
            context,
            day: record,
            activities: day.activities,
            breakStart: day.breakStart,
            breakMinutes: day.breakMinutes,
            now: _date == widget.today ? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}' : null,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Text(
          line,
          textAlign: TextAlign.center,
          style: JitanMobileTextStyles.pageSubtitle.copyWith(color: needsYou ? JitanColors.warning : null),
        ),
        if (!nothing) ...[
          const SizedBox(height: 20),
          HomeHero(
            label: context.t(EmployeeTextKeys.periodMonthRegistered),
            value: day.registeredMinutes == null ? context.t(EmployeeTextKeys.periodNotCounted) : PeriodText.duration(context, day.registeredMinutes!),
            smallValue: day.registeredMinutes == null,
            lines: [?PeriodText.totalLine(context, day)],
          ),
        ],
        if (stamps.isNotEmpty) ...[const SizedBox(height: 24), PeriodTimeline(stamps: stamps)],
        const SizedBox(height: 16),
      ],
    );
  }
}
