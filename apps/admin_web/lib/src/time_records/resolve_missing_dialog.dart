import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'rounded_time_controller.dart';
import 'time_correction_failure.dart';
import 'time_correction_fields.dart';
import 'time_correction_outcome.dart';
import 'time_record_card.dart';
import 'time_record_popup.dart';
import 'time_record_text.dart';

/// Figma `HR / Time records V2 — missing finish` (`1566:272`, "Not a work
/// day" `1566:529`), also for a missing start: HR adds the missing time
/// (rounded by the server, shown before saving) or marks the day not a work
/// day. The reason is typed: the ERD keeps it as text
/// (`tblTimeReg.timeRegComment`) and has no list of reasons.
class ResolveMissingDialog extends StatefulWidget {
  const ResolveMissingDialog({super.key, required this.api, required this.day, required this.companyId});

  final TimeRecordsApi api;
  /// A day with [TimeRecordStatus.missingStart] or
  /// [TimeRecordStatus.missingFinish].
  final TimeRecordDay day;
  final int companyId;

  @override
  State<ResolveMissingDialog> createState() => _ResolveMissingDialogState();
}

class _ResolveMissingDialogState extends State<ResolveMissingDialog> {
  late final RegistrationBoundary _missing = widget.day.status == TimeRecordStatus.missingStart
      ? RegistrationBoundary.start
      : RegistrationBoundary.finish;
  late final _time = RoundedTimeController(
    preview: (time) => widget.api.previewRounding(widget.companyId, widget.day.employeeId, widget.day.date, _missing, time),
  );
  final _reason = TextEditingController();
  bool _nonWork = false;
  String? _timeError;
  String? _reasonError;
  MessageFailure? _failure;
  bool _busy = false;

  bool get _finishMissing => _missing == RegistrationBoundary.finish;

  @override
  void dispose() {
    _time.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final reason = _reason.text.trim();
    setState(() {
      _failure = null;
      _timeError = !_nonWork && !_time.isValid ? AdminTextKeys.timeCorrectTimeInvalid : null;
      _reasonError = reason.isEmpty ? AdminTextKeys.timeCorrectReasonRequired : null;
    });
    if (_timeError != null || _reasonError != null) return;

    setState(() => _busy = true);
    final day = widget.day;
    try {
      if (_nonWork) {
        await widget.api.markNonWork(widget.companyId, day.employeeId, day.date, reason);
      } else {
        await widget.api.correct(
          widget.companyId,
          day.employeeId,
          day.date,
          CorrectTimeRequest(boundary: _missing, time: _time.value, reason: reason),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        _nonWork
            ? TimeCorrectionOutcome.nonWork
            : (_finishMissing ? TimeCorrectionOutcome.resolvedFinish : TimeCorrectionOutcome.resolvedStart),
      );
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (TimeCorrectionFailure.of(e)) {
          case TimeFieldFailure(:final key):
            _timeError = key;
          case ReasonFieldFailure(:final key):
            _reasonError = key;
          case final MessageFailure message:
            _failure = message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final known = _finishMissing ? day.start : day.finish;
    final knownBoundary = _finishMissing ? RegistrationBoundary.start : RegistrationBoundary.finish;
    // The time that is there, then the missing one, in the day's order.
    final knownRow = TimeRecordCardRow(
      label: TimeRecordText.boundary(context, knownBoundary),
      values: [
        TimeRecordCard.value(known?.actualLocal ?? '—'),
        TimeRecordCard.value(known?.roundedLocal ?? '—', strong: !_nonWork, muted: _nonWork),
      ],
    );
    final missingRow = TimeRecordCardRow(
      label: TimeRecordText.boundary(context, _missing),
      values: _nonWork
          ? [TimeRecordCard.value('—', muted: true), TimeRecordCard.value('—', muted: true)]
          : [
              TimeCardInput(
                time: _time,
                semanticLabel: TimeRecordText.boundary(context, _missing),
                failed: _timeError != null,
                enabled: !_busy,
              ),
              RoundedTimeValue(time: _time),
            ],
    );
    return TimeRecordPopup(
      title: context.t(_finishMissing ? AdminTextKeys.timeResolveFinishTitle : AdminTextKeys.timeResolveStartTitle),
      subtitle: '${TimeRecordText.name(day)} · ${TimeRecordText.dayDate(context, day.date)}',
      body: [
        JitanSegmentedSwitch<bool>(
          options: [
            (false, context.t(_finishMissing ? AdminTextKeys.timeResolveSetFinish : AdminTextKeys.timeResolveSetStart)),
            (true, context.t(AdminTextKeys.timeResolveNonWork)),
          ],
          value: _nonWork,
          onChanged: _busy ? null : (nonWork) => setState(() => _nonWork = nonWork),
        ),
        const SizedBox(height: 16),
        TimeRecordCard(
          widths: const [120, 110],
          headings: [context.t(AdminTextKeys.timeRecordCardActual), context.t(AdminTextKeys.timeRecordCardRounded)],
          rows: _finishMissing ? [knownRow, missingRow] : [missingRow, knownRow],
        ),
        if (_nonWork) ...[
          const SizedBox(height: 12),
          TimeRecordNotice(
            context.t(_finishMissing ? AdminTextKeys.timeResolveNonWorkFinishNote : AdminTextKeys.timeResolveNonWorkStartNote),
          ),
        ] else ...[
          if (_timeError case final error?) TimeCardError(context.t(error)),
          NoRoundingHint(times: [_time]),
        ],
        const SizedBox(height: 16),
        JitanTextField(
          label: context.t(AdminTextKeys.timeResolveReason),
          controller: _reason,
          hintText: context.t(AdminTextKeys.timeCorrectReasonHint),
          errorText: _reasonError == null ? null : context.t(_reasonError!),
          maxLength: RegisterTimeRequest.maxReasonLength,
        ),
        if (_failure case final failure?) ...[const SizedBox(height: 16), TimeCorrectionMessage(failure: failure)],
      ],
      bottom: TimeRecordNote(context.t(AdminTextKeys.timeResolveHistory)),
      actions: [
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop()),
        JitanPrimaryButton(
          label: context.t(_nonWork ? AdminTextKeys.timeResolveConfirmNonWork : AdminTextKeys.timeCorrectSave),
          busy: _busy,
          onPressed: _save,
        ),
      ],
    );
  }
}
