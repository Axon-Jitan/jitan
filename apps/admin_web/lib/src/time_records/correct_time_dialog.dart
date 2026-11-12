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

/// Figma `HR / Time records V2 — correct time` (`1566:788`), as
/// TIME_ENGINE_ANALYSIS D7: HR types the **actual** start and finish; the
/// **rounded** times are what the server's rounding makes of them, shown
/// beside them. Only the times HR changed are saved, each as a
/// "… – corrected" row with the reason (D4, D8: the original stays).
class CorrectTimeDialog extends StatefulWidget {
  const CorrectTimeDialog({super.key, required this.api, required this.day, required this.companyId});

  final TimeRecordsApi api;
  final TimeRecordDay day;
  final int companyId;

  @override
  State<CorrectTimeDialog> createState() => _CorrectTimeDialogState();
}

class _CorrectTimeDialogState extends State<CorrectTimeDialog> {
  late final _times = {
    for (final boundary in RegistrationBoundary.values)
      boundary: RoundedTimeController(
        preview: (time) => widget.api.previewRounding(widget.companyId, widget.day.employeeId, widget.day.date, boundary, time),
        initial: _side(boundary)?.actualLocal,
        initialRounded: _side(boundary)?.roundedLocal,
      ),
  };
  final _reason = TextEditingController();
  final _timeErrors = <RegistrationBoundary, String>{};
  String? _reasonError;
  MessageFailure? _failure;
  bool _busy = false;
  bool _savedAny = false;

  TimeRecordTime? _side(RegistrationBoundary boundary) =>
      boundary == RegistrationBoundary.start ? widget.day.start : widget.day.finish;

  @override
  void dispose() {
    for (final time in _times.values) {
      time.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final changed = [for (final MapEntry(key: b, value: t) in _times.entries) if (t.isChanged) b];
    final reason = _reason.text.trim();
    setState(() {
      _failure = null;
      _timeErrors
        ..clear()
        ..addAll({
          for (final b in changed)
            if (!_times[b]!.isValid) b: AdminTextKeys.timeCorrectTimeInvalid,
        });
      _reasonError = reason.isEmpty ? AdminTextKeys.timeCorrectReasonRequired : null;
      if (changed.isEmpty) _failure = const MessageFailure(AdminTextKeys.timeCorrectNothingChanged);
    });
    if (changed.isEmpty || _timeErrors.isNotEmpty || _reasonError != null) return;

    setState(() => _busy = true);
    for (final boundary in changed) {
      final time = _times[boundary]!;
      try {
        await widget.api.correct(
          widget.companyId,
          widget.day.employeeId,
          widget.day.date,
          CorrectTimeRequest(boundary: boundary, time: time.value, reason: reason),
        );
        time.markSaved();
        _savedAny = true;
      } on ApiClientException catch (e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          switch (TimeCorrectionFailure.of(e)) {
            case TimeFieldFailure(:final key):
              _timeErrors[boundary] = key;
            case ReasonFieldFailure(:final key):
              _reasonError = key;
            case final MessageFailure message:
              _failure = message;
          }
        });
        return;
      }
    }
    if (mounted) Navigator.of(context).pop(TimeCorrectionOutcome.corrected);
  }

  void _close() => Navigator.of(context).pop(_savedAny ? TimeCorrectionOutcome.partlySaved : null);

  @override
  Widget build(BuildContext context) {
    TimeRecordCardRow row(RegistrationBoundary boundary) {
      final label = TimeRecordText.boundary(context, boundary);
      return TimeRecordCardRow(
        label: label,
        values: [
          TimeCardInput(time: _times[boundary]!, semanticLabel: label, failed: _timeErrors[boundary] != null, enabled: !_busy),
          RoundedTimeValue(time: _times[boundary]!),
        ],
      );
    }

    final timeError = _timeErrors.values.firstOrNull;
    return TimeRecordPopup(
      title: context.t(AdminTextKeys.timeCorrectTitle),
      subtitle: '${TimeRecordText.name(widget.day)} · ${TimeRecordText.dayDate(context, widget.day.date)}',
      body: [
        TimeRecordCard(
          widths: const [120, 110],
          headings: [context.t(AdminTextKeys.timeRecordCardActual), context.t(AdminTextKeys.timeRecordCardRounded)],
          rows: [row(RegistrationBoundary.start), row(RegistrationBoundary.finish)],
        ),
        if (timeError != null) TimeCardError(context.t(timeError)),
        NoRoundingHint(times: _times.values.toList()),
        const SizedBox(height: 16),
        JitanTextField(
          label: context.t(AdminTextKeys.timeCorrectReason),
          controller: _reason,
          hintText: context.t(AdminTextKeys.timeCorrectReasonHint),
          errorText: _reasonError == null ? null : context.t(_reasonError!),
          maxLength: RegisterTimeRequest.maxReasonLength,
        ),
        if (_failure case final failure?) ...[const SizedBox(height: 16), TimeCorrectionMessage(failure: failure)],
      ],
      bottom: TimeRecordNote(context.t(AdminTextKeys.timeCorrectAuditText)),
      actions: [
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : _close),
        JitanPrimaryButton(label: context.t(AdminTextKeys.timeCorrectSave), busy: _busy, onPressed: _save),
      ],
    );
  }
}
