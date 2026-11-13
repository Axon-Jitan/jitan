import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/time_entry_parts.dart';
import '../today/time_picker_card.dart';
import '../widgets/phone_widgets.dart';
import 'period_text.dart';

/// Opens the page to add a past [day]'s missing start, finish or both
/// (Figma `1595:474`). Returns `true` once the server stored the time(s);
/// they then wait for HR (D31).
Future<bool> openMissingTime(BuildContext context, {required TimeRegistrationsApi api, required MyPeriodDay day}) async =>
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MissingTimeScreen(api: api, day: day),
      ),
    ) ??
    false;

/// A past day's missing time(s), entered by the employee with a reason, as
/// a correction (D30): stored as the actual time, rounded and counted only
/// once HR approves it (D31). The same page as Home's "Finished earlier?".
class MissingTimeScreen extends StatefulWidget {
  const MissingTimeScreen({super.key, required this.api, required this.day});

  final TimeRegistrationsApi api;
  final MyPeriodDay day;

  @override
  State<MissingTimeScreen> createState() => _MissingTimeScreenState();
}

class _MissingTimeScreenState extends State<MissingTimeScreen> {
  late final List<RegistrationBoundary> _missing = switch (widget.day.day?.status) {
    TimeRecordStatus.missingFinish => [RegistrationBoundary.finish],
    TimeRecordStatus.missingStart => [RegistrationBoundary.start],
    _ => [RegistrationBoundary.start, RegistrationBoundary.finish],
  };
  late final Map<RegistrationBoundary, (TextEditingController, TextEditingController)> _times = {
    for (final b in _missing) b: _initial(_scheduled(b)),
  };
  final _reason = TextEditingController();
  bool _busy = false;
  bool _order = false;
  ApiClientException? _failure;

  String? _scheduled(RegistrationBoundary b) => b == RegistrationBoundary.start ? widget.day.scheduledStart : widget.day.scheduledFinish;

  static (TextEditingController, TextEditingController) _initial(String? hhmm) {
    final parts = (hhmm ?? '').split(':');
    return (TextEditingController(text: parts.length == 2 ? parts[0] : ''), TextEditingController(text: parts.length == 2 ? parts[1] : ''));
  }

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
    for (final (h, m) in _times.values) {
      h.addListener(() => setState(() => _order = false));
      m.addListener(() => setState(() => _order = false));
    }
  }

  @override
  void dispose() {
    for (final (h, m) in _times.values) {
      h.dispose();
      m.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  int? _minutesOf(RegistrationBoundary b) {
    final (h, m) = _times[b]!;
    final hour = int.tryParse(h.text), minute = int.tryParse(m.text);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  bool get _ready => _missing.every((b) => _minutesOf(b) != null) && _reason.text.trim().isNotEmpty;

  static int? _local(String? hhmm) {
    final parts = (hhmm ?? '').split(':');
    if (parts.length != 2) return null;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Future<void> _save() async {
    final known = widget.day.day;
    final start = _times.containsKey(RegistrationBoundary.start)
        ? _minutesOf(RegistrationBoundary.start)
        : _local(known?.start?.actualLocal);
    final finish = _times.containsKey(RegistrationBoundary.finish)
        ? _minutesOf(RegistrationBoundary.finish)
        : _local(known?.finish?.actualLocal);
    if (start != null && finish != null && finish <= start) {
      setState(() => _order = true);
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    final date = widget.day.date;
    try {
      for (final b in _missing) {
        final minutes = _minutesOf(b)!;
        await widget.api.register(
          RegisterTimeRequest(
            boundary: b,
            method: TimeRegistrationMethod.manual,
            entry: RegistrationEntry.corrected,
            at: DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60).toUtc(),
            reason: _reason.text.trim(),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiClientException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final finishOnly = _missing.length == 1 && _missing.single == RegistrationBoundary.finish;
    final startOnly = _missing.length == 1 && _missing.single == RegistrationBoundary.start;
    final record = widget.day.day;
    final date = PeriodText.dayMonth(context, widget.day.date);
    final (title, text) = finishOnly
        ? (
            EmployeeTextKeys.periodSheetFinishTitle,
            context.t(EmployeeTextKeys.periodSheetFinishText, args: {'date': date, 'time': record?.start?.actualLocal ?? '--:--'}),
          )
        : startOnly
        ? (
            EmployeeTextKeys.periodSheetStartTitle,
            context.t(EmployeeTextKeys.periodSheetStartText, args: {'date': date, 'time': record?.finish?.actualLocal ?? '--:--'}),
          )
        : (EmployeeTextKeys.periodSheetBothTitle, context.t(EmployeeTextKeys.periodSheetBothText, args: {'date': date}));
    final failure = _failure;
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      appBar: phoneAppBar(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(header: true, child: Text(context.t(title), style: JitanMobileTextStyles.pageTitle)),
                      const SizedBox(height: 6),
                      Text(text, style: JitanMobileTextStyles.pageSubtitle),
                      for (final b in _missing) ..._time(context, b),
                      if (_order) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.t(EmployeeTextKeys.periodSheetTimeOrder),
                          style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.errorStrong, fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(context.t(EmployeeTextKeys.entryReason), style: JitanMobileTextStyles.label),
                      const SizedBox(height: 8),
                      EntryReasonField(controller: _reason, hint: context.t(EmployeeTextKeys.periodSheetCommentHint)),
                      const SizedBox(height: 8),
                      Text(context.t(EmployeeTextKeys.entryReasonHelp), style: JitanMobileTextStyles.detail),
                    ],
                  ),
                ),
              ),
              if (failure != null) ...[
                PhoneErrorNote(
                  title: context.t(EmployeeTextKeys.todaySaveFinishFailed),
                  message: context.t(
                    failure.kind == ApiFailureKind.network ? EmployeeTextKeys.todayCheckConnection : EmployeeTextKeys.todaySaveRefused,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              JitanMobileButton(
                label: context.t(EmployeeTextKeys.periodSheetSave),
                size: JitanMobileButtonSize.phone,
                busy: _busy,
                onPressed: _ready ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Finish time", the big time and "Scheduled finish 16:30 · Use it".
  List<Widget> _time(BuildContext context, RegistrationBoundary b) {
    final start = b == RegistrationBoundary.start;
    final (hours, minutes) = _times[b]!;
    final scheduled = _scheduled(b);
    return [
      const SizedBox(height: 24),
      Text(context.t(start ? EmployeeTextKeys.entryStartTime : EmployeeTextKeys.entryFinishTime), style: JitanMobileTextStyles.label),
      const SizedBox(height: 8),
      TimePickerCard(hours: hours, minutes: minutes, error: _order),
      if (scheduled != null) ...[
        const SizedBox(height: 4),
        ScheduledTimeRow(
          label: '${context.t(start ? EmployeeTextKeys.entryScheduledStart : EmployeeTextKeys.entryScheduledFinish)} $scheduled',
          useLabel: context.t(EmployeeTextKeys.entryUseScheduled),
          onUse: _busy
              ? null
              : () {
                  final parts = scheduled.split(':');
                  hours.text = parts[0];
                  minutes.text = parts[1];
                },
        ),
      ],
    ];
  }
}

/// The label of the button on a day that misses a time.
String missingTimeAction(BuildContext context, MyPeriodDay day) => context.t(switch (day.day?.status) {
  TimeRecordStatus.missingFinish => EmployeeTextKeys.periodFixFinish,
  TimeRecordStatus.missingStart => EmployeeTextKeys.periodFixStart,
  _ => EmployeeTextKeys.periodFixBoth,
});

/// Whether the employee can add the missing time(s) of [day] themselves.
bool canFixMissing(MyPeriodDay day) => switch (day.day?.status) {
  TimeRecordStatus.missingFinish || TimeRecordStatus.missingStart || TimeRecordStatus.noRegistration => true,
  _ => false,
};
