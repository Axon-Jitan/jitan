import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import 'missing_time_sheet.dart';
import 'period_text.dart';
import 'period_widgets.dart';

/// "Day details" (Figma 99:56, no activity 99:121): one day with its
/// registered time, status, planned and actual times and timeline; the
/// arrows step through days. A day with a missing start or finish offers to
/// add it ("Missing end time", 100:2).
class DayDetailsScreen extends StatefulWidget {
  const DayDetailsScreen({
    super.key,
    required this.api,
    required this.date,
    required this.today,
    required this.onSessionEnded,
    this.bottomBar,
  });

  final TimeRegistrationsApi api;
  final DateTime date;

  /// No stepping past today.
  final DateTime today;
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

  void _step(int days) {
    _date = DateTime.utc(_date.year, _date.month, _date.day + days);
    _load();
  }

  Future<void> _fix(MyPeriodDay day) async {
    if (await showMissingTimeSheet(context, api: widget.api, day: day) && mounted) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_changed);
    },
    child: Scaffold(
      backgroundColor: JitanColors.warmWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.chevron_left, size: 28, color: JitanColors.ink),
                  ),
                  Semantics(header: true, child: Text(context.t(EmployeeTextKeys.periodDayTitle), style: JitanMobileTextStyles.formTitle)),
                ],
              ),
              const SizedBox(height: 18),
              _dateBar(context),
              const SizedBox(height: 20),
              Expanded(child: SingleChildScrollView(child: _content(context))),
              if (widget.bottomBar case final bar?) ...[const SizedBox(height: 16), bar],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _dateBar(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: JitanColors.inputBorder)),
    child: Row(
      children: [
        IconButton(
          tooltip: context.t(EmployeeTextKeys.periodDayPrevious),
          onPressed: _loading ? null : () => _step(-1),
          icon: const Icon(Icons.chevron_left, color: JitanColors.ink),
        ),
        Expanded(
          child: Text(PeriodText.fullDate(context, _date), textAlign: TextAlign.center, style: JitanMobileTextStyles.summary.copyWith(fontSize: 15)),
        ),
        IconButton(
          tooltip: context.t(EmployeeTextKeys.periodDayNext),
          onPressed: _loading || !_date.isBefore(widget.today) ? null : () => _step(1),
          icon: const Icon(Icons.chevron_right, color: JitanColors.ink),
        ),
      ],
    ),
  );

  Widget _content(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator(color: JitanColors.ink, strokeWidth: 2)));
    }
    if (_failure != null) {
      return Column(
        children: [
          const SizedBox(height: 60),
          Text(context.t(EmployeeTextKeys.periodLoadFailed), style: JitanMobileTextStyles.cardTitle),
          const SizedBox(height: 16),
          JitanMobileButton(label: context.t(EmployeeTextKeys.todayTryAgain), onPressed: _load),
        ],
      );
    }
    final day = _day;
    final record = day?.day;
    if (day == null || (record == null && day.plannedMinutes == null)) return _noActivity(context);
    final start = record?.start, finish = record?.finish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeriodTotalCard(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.registeredMinutes == null ? '—' : PeriodText.hours(context, day.registeredMinutes!), style: PeriodTotalCard.big()),
                      const SizedBox(height: 2),
                      Text(context.t(EmployeeTextKeys.periodRegistered), style: PeriodTotalCard.small()),
                    ],
                  ),
                ),
                if (record != null) PeriodBadge(label: PeriodText.status(context, record.status), color: PeriodText.statusColor(record.status)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    record == null
                        ? context.t(EmployeeTextKeys.periodDayPlanned, args: {'range': '${day.scheduledStart} — ${day.scheduledFinish}'})
                        : '${start?.roundedLocal ?? start?.actualLocal ?? '--:--'} — ${finish?.roundedLocal ?? finish?.actualLocal ?? '--:--'}',
                    style: PeriodTotalCard.small().copyWith(color: JitanColors.warmWhite, fontSize: 13),
                  ),
                ),
                if (start != null || finish != null)
                  Text(
                    context.t(EmployeeTextKeys.periodDayActual, args: {'range': '${start?.actualLocal ?? '--:--'} — ${finish?.actualLocal ?? '--:--'}'}),
                    style: PeriodTotalCard.small().copyWith(fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
        if (canFixMissing(day)) ...[
          const SizedBox(height: 14),
          JitanMobileButton(label: missingTimeAction(context, day), onPressed: () => _fix(day)),
        ],
        if (record != null && record.events.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text(context.t(EmployeeTextKeys.periodTimeline), style: JitanMobileTextStyles.fieldLabel),
          const SizedBox(height: 16),
          PeriodTimeline(events: record.events, pending: record.pending),
        ],
      ],
    );
  }

  Widget _noActivity(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 90),
    child: Column(
      children: [
        const Icon(Icons.event_note_outlined, size: 36, color: JitanColors.inkMuted),
        const SizedBox(height: 16),
        Text(context.t(EmployeeTextKeys.periodDayNoActivity), style: JitanMobileTextStyles.cardTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 8),
        Text(context.t(EmployeeTextKeys.periodDayNoActivityText), textAlign: TextAlign.center, style: JitanMobileTextStyles.body),
      ],
    ),
  );
}
