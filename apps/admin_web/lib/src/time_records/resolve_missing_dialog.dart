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
import 'time_record_text.dart';

/// Figma `HR / Time records — Resolve missing finish` (272:457, with "Mark
/// as non-work" 273:166), also for a missing start: HR sets the missing time
/// (rounded by the server, shown before saving) or marks the day non-work.
///
/// Different from Figma, on purpose: the reason is typed, not picked from a
/// list. The ERD keeps a reason as text (`tblTimeReg.timeRegComment`) and has
/// no list of reasons to choose from.
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
  Widget build(BuildContext context) => JitanModal(
    width: 640,
    title: context.t(_finishMissing ? AdminTextKeys.timeResolveFinishTitle : AdminTextKeys.timeResolveStartTitle),
    subtitle: '${TimeRecordText.name(widget.day)} · ${TimeRecordText.longDate(context, widget.day.date)}',
    onClose: _busy ? null : () => Navigator.of(context).pop(),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _details(context),
        const SizedBox(height: 20),
        Text(context.t(AdminTextKeys.timeResolveChoose), style: JitanTextStyles.tableCellStrong),
        const SizedBox(height: 12),
        _choice(
          context,
          selected: !_nonWork,
          title: _finishMissing ? AdminTextKeys.timeResolveSetFinish : AdminTextKeys.timeResolveSetStart,
          text: _finishMissing ? AdminTextKeys.timeResolveSetFinishText : AdminTextKeys.timeResolveSetStartText,
          onTap: () => setState(() => _nonWork = false),
        ),
        const SizedBox(height: 10),
        _choice(
          context,
          selected: _nonWork,
          title: AdminTextKeys.timeResolveNonWork,
          text: AdminTextKeys.timeResolveNonWorkText,
          onTap: () => setState(() => _nonWork = true),
        ),
        const SizedBox(height: 18),
        if (_nonWork)
          TimeCorrectionNote(
            text: context.t(_finishMissing ? AdminTextKeys.timeResolveNonWorkFinishNote : AdminTextKeys.timeResolveNonWorkStartNote),
            color: JitanColors.inkMuted,
            background: JitanColors.noteSurface,
          )
        else ...[
          TimeFieldPair(
            first: TimeInputField(
              label: context.t(_finishMissing ? AdminTextKeys.timeResolveActualFinish : AdminTextKeys.timeResolveActualStart),
              time: _time,
              errorText: _timeError == null ? null : context.t(_timeError!),
            ),
            second: RoundedTimeField(
              label: context.t(_finishMissing ? AdminTextKeys.timeResolveRoundedFinish : AdminTextKeys.timeResolveRoundedStart),
              time: _time,
            ),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: RoundedTimeHint(times: [_time])),
        ],
        const SizedBox(height: 18),
        JitanTextField(
          label: context.t(AdminTextKeys.timeResolveReason),
          controller: _reason,
          hintText: context.t(AdminTextKeys.timeCorrectReasonHint),
          errorText: _reasonError == null ? null : context.t(_reasonError!),
          maxLength: RegisterTimeRequest.maxReasonLength,
        ),
        const SizedBox(height: 6),
        Text(context.t(AdminTextKeys.timeResolveHistory), style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
        if (_failure case final failure?) ...[const SizedBox(height: 16), TimeCorrectionMessage(failure: failure)],
      ],
    ),
    actions: [
      JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy ? null : () => Navigator.of(context).pop()),
      JitanPrimaryButton(
        label: context.t(_nonWork ? AdminTextKeys.timeResolveConfirmNonWork : AdminTextKeys.timeCorrectSave),
        busy: _busy,
        onPressed: _save,
      ),
    ],
  );

  /// The time that is there, and the status (Figma "Registration details").
  Widget _details(BuildContext context) {
    final known = _finishMissing ? widget.day.start : widget.day.finish;
    final muted = JitanTextStyles.stateMessage.copyWith(fontSize: 12);
    final big = JitanTextStyles.pageTitle.copyWith(fontSize: 20);
    Widget value(String labelKey, String? time) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(labelKey), style: muted),
          const SizedBox(height: 4),
          Text(time ?? '—', style: big),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: JitanColors.noteSurface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(context.t(AdminTextKeys.timeResolveDetails), style: JitanTextStyles.tableCellStrong)),
              Text(
                TimeRecordText.status(context, widget.day.status),
                style: JitanTextStyles.tableCell.copyWith(color: TimeRecordText.statusColor(widget.day.status), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: JitanColors.inputBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              value(_finishMissing ? AdminTextKeys.timeResolveActualStart : AdminTextKeys.timeResolveActualFinish, known?.actualLocal),
              const SizedBox(width: 16),
              value(_finishMissing ? AdminTextKeys.timeResolveRoundedStart : AdminTextKeys.timeResolveRoundedFinish, known?.roundedLocal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _choice(BuildContext context, {required bool selected, required String title, required String text, required VoidCallback onTap}) =>
      Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        child: InkWell(
          onTap: _busy ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? JitanColors.vermilion : JitanColors.surface,
                    border: Border.all(color: selected ? JitanColors.vermilion : JitanColors.radioBorder),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t(title), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(context.t(text), style: JitanTextStyles.stateMessage.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
