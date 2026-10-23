import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/time_picker_card.dart';
import '../today/today_widgets.dart';
import 'period_text.dart';

/// Opens "Missing end time" for a past [day] (Figma 100:2). Returns `true`
/// once the server stored the time(s); they then wait for HR (D31).
Future<bool> showMissingTimeSheet(BuildContext context, {required TimeRegistrationsApi api, required MyPeriodDay day}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: JitanColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => MissingTimeSheet(api: api, day: day),
    ) ??
    false;

/// A past day's missing start, finish or both, entered by the employee with
/// a comment, as a correction (D30): stored as the actual time, rounded and
/// counted only once HR approves it (D31).
///
/// Different from Figma 100:2, on purpose: the rounding note does not quote
/// "Start: 08:03 → 08:00" (a correction is rounded when HR approves it), and
/// a day with neither start nor finish asks for both.
class MissingTimeSheet extends StatefulWidget {
  const MissingTimeSheet({super.key, required this.api, required this.day});

  final TimeRegistrationsApi api;
  final MyPeriodDay day;

  @override
  State<MissingTimeSheet> createState() => _MissingTimeSheetState();
}

class _MissingTimeSheetState extends State<MissingTimeSheet> {
  late final List<RegistrationBoundary> _missing = switch (widget.day.day?.status) {
    TimeRecordStatus.missingFinish => [RegistrationBoundary.finish],
    TimeRecordStatus.missingStart => [RegistrationBoundary.start],
    _ => [RegistrationBoundary.start, RegistrationBoundary.finish],
  };
  late final Map<RegistrationBoundary, (TextEditingController, TextEditingController)> _times = {
    for (final b in _missing) b: _initial(b == RegistrationBoundary.start ? widget.day.scheduledStart : widget.day.scheduledFinish),
  };
  final _comment = TextEditingController();
  bool _busy = false;
  String? _errorKey;
  ApiClientException? _failure;

  static (TextEditingController, TextEditingController) _initial(String? hhmm) {
    final parts = (hhmm ?? '').split(':');
    return (TextEditingController(text: parts.length == 2 ? parts[0] : ''), TextEditingController(text: parts.length == 2 ? parts[1] : ''));
  }

  @override
  void initState() {
    super.initState();
    _comment.addListener(() => setState(() {}));
    for (final (h, m) in _times.values) {
      h.addListener(() => setState(() => _errorKey = null));
      m.addListener(() => setState(() => _errorKey = null));
    }
  }

  @override
  void dispose() {
    for (final (h, m) in _times.values) {
      h.dispose();
      m.dispose();
    }
    _comment.dispose();
    super.dispose();
  }

  int? _minutesOf(RegistrationBoundary b) {
    final (h, m) = _times[b]!;
    final hour = int.tryParse(h.text), minute = int.tryParse(m.text);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  bool get _ready => _missing.every((b) => _minutesOf(b) != null) && _comment.text.trim().isNotEmpty;

  Future<void> _save() async {
    final known = widget.day.day;
    final start = _times.containsKey(RegistrationBoundary.start) ? _minutesOf(RegistrationBoundary.start) : _local(known?.start?.actualLocal);
    final finish = _times.containsKey(RegistrationBoundary.finish) ? _minutesOf(RegistrationBoundary.finish) : _local(known?.finish?.actualLocal);
    if (start != null && finish != null && finish <= start) {
      setState(() => _errorKey = EmployeeTextKeys.periodSheetTimeOrder);
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
            reason: _comment.text.trim(),
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

  static int? _local(String? hhmm) {
    final parts = (hhmm ?? '').split(':');
    if (parts.length != 2) return null;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    final finishOnly = _missing.length == 1 && _missing.single == RegistrationBoundary.finish;
    final startOnly = _missing.length == 1 && _missing.single == RegistrationBoundary.start;
    final title = finishOnly
        ? EmployeeTextKeys.periodSheetFinishTitle
        : startOnly
        ? EmployeeTextKeys.periodSheetStartTitle
        : EmployeeTextKeys.periodSheetBothTitle;
    final text = finishOnly
        ? EmployeeTextKeys.periodSheetFinishText
        : startOnly
        ? EmployeeTextKeys.periodSheetStartText
        : EmployeeTextKeys.periodSheetBothText;
    final known = finishOnly ? widget.day.day?.start : (startOnly ? widget.day.day?.finish : null);
    final failure = _failure;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: JitanColors.inputBorder, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text(context.t(title), style: JitanMobileTextStyles.formTitle.copyWith(fontSize: 22))),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close, color: JitanColors.inkMuted),
                ),
              ],
            ),
            Text(context.t(text), style: JitanMobileTextStyles.body.copyWith(fontSize: 13)),
            const SizedBox(height: 18),
            if (known != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(finishOnly ? EmployeeTextKeys.periodSheetStarted : EmployeeTextKeys.periodSheetFinished),
                      style: JitanMobileTextStyles.cardText,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(known.roundedLocal ?? known.actualLocal, style: JitanMobileTextStyles.identityName),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(context.t(EmployeeTextKeys.periodSheetRegistered), style: JitanMobileTextStyles.cardText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(context.t(EmployeeTextKeys.periodSheetActual, args: {'time': known.actualLocal}), style: JitanMobileTextStyles.cardText.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            for (final b in _missing) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.t(b == RegistrationBoundary.start ? EmployeeTextKeys.periodSheetAskStart : EmployeeTextKeys.periodSheetAskFinish),
                      style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14),
                    ),
                  ),
                  SizedBox(width: 132, child: TimePickerCard(hours: _times[b]!.$1, minutes: _times[b]!.$2, compact: true)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_errorKey case final key?) ...[
              Text(context.t(key), style: JitanMobileTextStyles.fieldError.copyWith(fontSize: 12)),
              const SizedBox(height: 10),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(EmployeeTextKeys.periodSheetRounding), style: JitanMobileTextStyles.noteTitleLarge),
                  const SizedBox(height: 4),
                  Text(context.t(EmployeeTextKeys.periodSheetRoundingText), style: JitanMobileTextStyles.cardText),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(context.t(EmployeeTextKeys.periodSheetComment), style: JitanMobileTextStyles.fieldLabel),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              minLines: 3,
              maxLines: 3,
              maxLength: RegisterTimeRequest.maxReasonLength,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              style: JitanMobileTextStyles.summary.copyWith(fontSize: 14),
              decoration: InputDecoration(
                hintText: context.t(EmployeeTextKeys.periodSheetCommentHint),
                hintStyle: JitanMobileTextStyles.fieldHint,
                filled: true,
                fillColor: JitanColors.surface,
                contentPadding: const EdgeInsets.all(14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: JitanColors.inputBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: JitanColors.ink)),
              ),
            ),
            if (failure != null) ...[
              const SizedBox(height: 14),
              TodayErrorBox(
                title: context.t(EmployeeTextKeys.todaySaveFinishFailed),
                message: context.t(
                  failure.kind == ApiFailureKind.network ? EmployeeTextKeys.todayCheckConnection : EmployeeTextKeys.todaySaveRefused,
                ),
              ),
            ],
            const SizedBox(height: 18),
            JitanMobileButton(
              label: context.t(failure != null ? EmployeeTextKeys.todayTryAgain : EmployeeTextKeys.periodSheetSave),
              busy: _busy,
              onPressed: _ready ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-line text of the fix button on Day details.
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

/// The badge colour on Day details, by status.
Color dayBadgeColor(TimeRecordStatus status) => PeriodText.statusColor(status);
