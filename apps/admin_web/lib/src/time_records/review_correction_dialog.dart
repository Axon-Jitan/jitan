import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_correction_failure.dart';
import 'time_correction_fields.dart';
import 'time_correction_outcome.dart';
import 'time_record_card.dart';
import 'time_record_popup.dart';
import 'time_record_text.dart';

/// Figma `HR / Time records V2 — review a correction` (`1566:1040`): what
/// was registered, what the employee asked and what that counts as after
/// rounding, with their reason. It counts only once HR approves it (D31).
/// When the employee corrected both start and finish, both are approved or
/// rejected together. When they were entered is not shown: the server does
/// not send it.
class ReviewCorrectionDialog extends StatefulWidget {
  const ReviewCorrectionDialog({super.key, required this.api, required this.day, required this.companyId});

  final TimeRecordsApi api;

  /// A day with [TimeRecordDay.pending] corrections.
  final TimeRecordDay day;
  final int companyId;

  @override
  State<ReviewCorrectionDialog> createState() => _ReviewCorrectionDialogState();
}

class _ReviewCorrectionDialogState extends State<ReviewCorrectionDialog> {
  /// Which button is saving.
  TimeCorrectionOutcome? _busy;
  MessageFailure? _failure;
  final _done = <int>{};

  TimeRecordDay get _day => widget.day;

  TimeRecordPending? _pending(RegistrationBoundary boundary) =>
      _day.pending.where((p) => p.boundary == boundary).firstOrNull;

  TimeRecordTime? _side(RegistrationBoundary boundary) => boundary == RegistrationBoundary.start ? _day.start : _day.finish;

  Future<void> _decide(TimeCorrectionOutcome outcome) async {
    setState(() {
      _busy = outcome;
      _failure = null;
    });
    try {
      for (final pending in _day.pending) {
        if (_done.contains(pending.id)) continue;
        if (outcome == TimeCorrectionOutcome.approved) {
          await widget.api.approve(widget.companyId, _day.employeeId, pending.id);
        } else {
          await widget.api.reject(widget.companyId, _day.employeeId, pending.id);
        }
        _done.add(pending.id);
      }
      if (mounted) Navigator.of(context).pop(outcome);
    } on ApiClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _failure = switch (TimeCorrectionFailure.of(e)) {
          final MessageFailure message => message,
          _ => MessageFailure.keys((title: CommonTextKeys.errorUnexpectedTitle, message: CommonTextKeys.errorUnexpectedMessage)),
        };
      });
    }
  }

  void _close() => Navigator.of(context).pop(_done.isEmpty ? null : TimeCorrectionOutcome.partlySaved);

  @override
  Widget build(BuildContext context) {
    final reasons = {for (final p in _day.pending) ?p.reason}.where((r) => r.isNotEmpty).join('\n');
    TimeRecordCardRow row(RegistrationBoundary boundary) {
      final side = _side(boundary);
      final pending = _pending(boundary);
      // What the employee asked is strong only where it changes something.
      return TimeRecordCardRow(
        label: TimeRecordText.boundary(context, boundary),
        values: [
          TimeRecordCard.value(side?.actualLocal ?? '—', muted: true),
          TimeRecordCard.value(pending?.requestedLocal ?? side?.actualLocal ?? '—', strong: pending != null, muted: pending == null),
          TimeRecordCard.value(
            pending?.roundedLocal ?? side?.roundedLocal ?? '—',
            strong: pending != null,
            muted: pending == null,
          ),
        ],
      );
    }

    return TimeRecordPopup(
      title: context.t(AdminTextKeys.timeReviewTitle),
      subtitle: context.t(
        AdminTextKeys.timeReviewSubtitle,
        args: {'name': TimeRecordText.name(_day), 'date': TimeRecordText.dayDate(context, _day.date)},
      ),
      body: [
        TimeRecordCard(
          widths: const [100, 100, 90],
          headings: [
            context.t(AdminTextKeys.timeRecordCardRegistered),
            context.t(AdminTextKeys.timeRecordCardAsked),
            context.t(AdminTextKeys.timeRecordCardRounded),
          ],
          rows: [row(RegistrationBoundary.start), row(RegistrationBoundary.finish)],
        ),
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t(AdminTextKeys.timeReviewReason), style: JitanTextStyles.fieldLabel),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: JitanColors.tableHeader, borderRadius: BorderRadius.circular(12)),
            child: Text('“$reasons”', style: JitanTextStyles.tableCell.copyWith(fontSize: 15, color: JitanColors.ink)),
          ),
        ],
        if (_failure case final failure?) ...[const SizedBox(height: 16), TimeCorrectionMessage(failure: failure)],
      ],
      bottom: TimeRecordNote(context.t(AdminTextKeys.timeReviewRule)),
      leadingActions: [
        TextButton(
          onPressed: _busy != null ? null : () => _decide(TimeCorrectionOutcome.rejected),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), minimumSize: Size.zero),
          child: Text(
            context.t(AdminTextKeys.timeReviewReject),
            style: JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.errorStrong),
          ),
        ),
      ],
      actions: [
        JitanSecondaryButton(label: context.t(CommonTextKeys.cancel), onPressed: _busy != null ? null : _close),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.timeReviewApprove),
          busy: _busy == TimeCorrectionOutcome.approved,
          onPressed: _busy != null ? null : () => _decide(TimeCorrectionOutcome.approved),
        ),
      ],
    );
  }
}
