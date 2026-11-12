import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/phone_widgets.dart';
import 'time_picker_card.dart';

/// "When did you arrive?" / "When did you finish?" (Figma 1436:2, 1436:43,
/// 1436:84, 1436:172) and the first day's "When did you arrive?" (22:2).
///
/// A **correction** (D30) needs a reason and waits for HR (D31). The **first
/// day**, right after onboarding, needs none.
///
/// Left out of 22:2 on purpose: the "BRANCH MOUSCRON" location chip. Jitan
/// doesn't know the workplace before geofencing (phase 4).
class TimeEntryScreen extends StatefulWidget {
  const TimeEntryScreen({
    super.key,
    required this.boundary,
    required this.entry,
    required this.scheduled,
    required this.now,
    required this.onConfirm,
    this.bottomBar,
  });

  final RegistrationBoundary boundary;

  /// [RegistrationEntry.corrected] or [RegistrationEntry.firstDay].
  final RegistrationEntry entry;

  /// Today's scheduled start or finish (`HH:mm`), or `null`.
  final String? scheduled;
  final DateTime Function() now;

  /// Sends the time; throws [ApiClientException] when it is not saved.
  final Future<void> Function(int hour, int minute, String? reason) onConfirm;

  /// The navigation bar, when the screen is shown in place of Today.
  final Widget? bottomBar;

  @override
  State<TimeEntryScreen> createState() => _TimeEntryScreenState();
}

class _TimeEntryScreenState extends State<TimeEntryScreen> {
  late final _hours = TextEditingController();
  late final _minutes = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  bool _future = false;
  ApiClientException? _failure;

  bool get _isStart => widget.boundary == RegistrationBoundary.start;
  bool get _needsReason => widget.entry == RegistrationEntry.corrected;

  @override
  void initState() {
    super.initState();
    // The first day starts from the schedule (22:2); a correction from now.
    final scheduled = _parse(widget.scheduled);
    if (widget.entry == RegistrationEntry.firstDay && scheduled != null) {
      _set(scheduled.$1, scheduled.$2);
    } else {
      final now = widget.now();
      _set(now.hour, now.minute);
    }
    for (final c in [_hours, _minutes, _reason]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() => _future = false);

  @override
  void dispose() {
    for (final c in [_hours, _minutes, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  static (int, int)? _parse(String? hhmm) {
    final match = RegExp(r'^(\d\d):(\d\d)$').firstMatch(hhmm ?? '');
    return match == null ? null : (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  void _set(int hour, int minute) {
    _hours.text = hour.toString().padLeft(2, '0');
    _minutes.text = minute.toString().padLeft(2, '0');
  }

  (int, int)? get _time {
    final h = int.tryParse(_hours.text);
    final m = int.tryParse(_minutes.text);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return (h, m);
  }

  bool get _ready => _time != null && (!_needsReason || _reason.text.trim().isNotEmpty);

  Future<void> _confirm() async {
    final (hour, minute) = _time!;
    final now = widget.now();
    if (DateTime(now.year, now.month, now.day, hour, minute).isAfter(now)) {
      setState(() => _future = true);
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await widget.onConfirm(hour, minute, _needsReason ? _reason.text.trim() : null);
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on ApiClientException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = e;
        });
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final firstDay = widget.entry == RegistrationEntry.firstDay;
    final title = _isStart ? EmployeeTextKeys.entryArriveTitle : EmployeeTextKeys.entryFinishTitle;
    final text = switch (widget.entry) {
      RegistrationEntry.firstDay => EmployeeTextKeys.entryFirstDayText,
      _ => _isStart ? EmployeeTextKeys.entryArriveText : EmployeeTextKeys.entryFinishText,
    };
    final confirm = _isStart ? EmployeeTextKeys.entryConfirmStart : EmployeeTextKeys.entryConfirmFinish;
    return Scaffold(
      backgroundColor: JitanColors.warmWhite,
      // In place of Home on the first day: the logo, no way back.
      appBar: widget.bottomBar == null ? phoneAppBar(context) : null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, widget.bottomBar == null ? 0 : 10, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.bottomBar != null) ...[
                        const Align(alignment: Alignment.centerLeft, child: JitanWordmark()),
                        const SizedBox(height: 26),
                      ],
                      Semantics(header: true, child: Text(context.t(title), style: JitanMobileTextStyles.pageTitle)),
                      const SizedBox(height: 6),
                      Text(context.t(text), style: JitanMobileTextStyles.pageSubtitle),
                      const SizedBox(height: 24),
                      Text(
                        context.t(_isStart ? EmployeeTextKeys.entryStartTime : EmployeeTextKeys.entryFinishTime),
                        style: JitanMobileTextStyles.label,
                      ),
                      const SizedBox(height: 8),
                      TimePickerCard(hours: _hours, minutes: _minutes, error: _future),
                      if (_future) ...[
                        const SizedBox(height: 8),
                        Text(
                          context.t(EmployeeTextKeys.entryTimeFuture),
                          style: JitanMobileTextStyles.detail.copyWith(color: JitanColors.errorStrong, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (widget.scheduled case final scheduled?) ...[
                        const SizedBox(height: 4),
                        firstDay
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                                child: Text(
                                  context.t(EmployeeTextKeys.entryScheduleStartsAt, args: {'time': scheduled}),
                                  style: JitanMobileTextStyles.detail.copyWith(fontSize: 14),
                                ),
                              )
                            : _scheduledRow(context, scheduled),
                      ],
                      if (_needsReason) ...[
                        const SizedBox(height: 16),
                        Text(context.t(EmployeeTextKeys.entryReason), style: JitanMobileTextStyles.label),
                        const SizedBox(height: 8),
                        _reasonField(context),
                        const SizedBox(height: 8),
                        Text(context.t(EmployeeTextKeys.entryReasonHelp), style: JitanMobileTextStyles.detail),
                      ],
                    ],
                  ),
                ),
              ),
              if (failure != null) ...[
                PhoneErrorNote(
                  title: context.t(_isStart ? EmployeeTextKeys.todaySaveStartFailed : EmployeeTextKeys.todaySaveFinishFailed),
                  message: context.t(
                    failure.kind == ApiFailureKind.network ? EmployeeTextKeys.todayCheckConnection : EmployeeTextKeys.todaySaveRefused,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              JitanMobileButton(
                label: context.t(confirm),
                size: JitanMobileButtonSize.phone,
                busy: _busy,
                onPressed: _ready ? _confirm : null,
              ),
              if (widget.bottomBar case final bar?) ...[const SizedBox(height: 16), bar],
            ],
          ),
        ),
      ),
    );
  }

  /// "Scheduled start 08:00 · Use it".
  Widget _scheduledRow(BuildContext context, String scheduled) => Row(
    children: [
      const SizedBox(width: 2),
      Expanded(
        child: Text(
          '${context.t(_isStart ? EmployeeTextKeys.entryScheduledStart : EmployeeTextKeys.entryScheduledFinish)} $scheduled',
          style: JitanMobileTextStyles.detail.copyWith(fontSize: 14),
        ),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () {
                final time = _parse(scheduled);
                if (time != null) _set(time.$1, time.$2);
              },
        style: TextButton.styleFrom(foregroundColor: JitanColors.ink, minimumSize: const Size(44, 44)),
        child: Text(
          context.t(EmployeeTextKeys.entryUseScheduled),
          style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 14),
        ),
      ),
    ],
  );

  Widget _reasonField(BuildContext context) {
    OutlineInputBorder border(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color));
    return TextField(
      controller: _reason,
      minLines: 3,
      maxLines: 3,
      maxLength: RegisterTimeRequest.maxReasonLength,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      style: JitanMobileTextStyles.rowText.copyWith(height: 1.4),
      cursorColor: JitanColors.ink,
      decoration: InputDecoration(
        hintText: context.t(EmployeeTextKeys.entryReasonHint),
        hintStyle: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted, height: 1.4),
        filled: true,
        fillColor: JitanColors.surface,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: border(JitanColors.inputBorder),
        focusedBorder: border(JitanColors.ink),
      ),
    );
  }
}
