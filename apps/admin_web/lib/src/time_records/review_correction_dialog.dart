import 'package:flutter/material.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_correction_failure.dart';
import 'time_correction_fields.dart';
import 'time_correction_outcome.dart';
import 'time_record_text.dart';

/// Figma `HR / Time records — Review correction` (160:338): the employee's
/// correction next to what was detected, and what it would count as after
/// rounding. It counts only once HR approves it (D31).
///
/// Different from Figma, on purpose:
/// - **Reject** and **Approve** are added: the frame has no buttons, and D31
///   needs HR's decision.
/// - "Submitted 09:14 today" is left out: the server does not send when the
///   correction was entered.
/// - When the employee corrected both start and finish, both are reviewed
///   together and approved or rejected together.
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

  /// "07:01 — 15:32" as in Figma; a time that is not there is "--:--".
  String _range(String? Function(RegistrationBoundary) of) =>
      '${of(RegistrationBoundary.start) ?? '--:--'} — ${of(RegistrationBoundary.finish) ?? '--:--'}';

  /// Every requested time counts as what already counts after rounding.
  bool get _noPayrollChange => _day.pending.every((p) => p.roundedLocal != null && p.roundedLocal == _side(p.boundary)?.roundedLocal);

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
    final muted = JitanTextStyles.stateMessage.copyWith(fontSize: 12);
    final big = JitanTextStyles.pageTitle.copyWith(fontSize: 18);
    final registered = _range((b) => _pending(b)?.roundedLocal ?? _side(b)?.roundedLocal);
    final reasons = {for (final p in _day.pending) ?p.reason}.join('\n');

    Widget value(String labelKey, String text, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.t(labelKey), style: muted),
        const SizedBox(height: 8),
        Text(text, style: big.copyWith(color: color)),
      ],
    );
    Widget pair(Widget first, Widget second) => LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 400
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, const SizedBox(height: 16), second])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Expanded(child: first), const SizedBox(width: 16), Expanded(child: second)],
            ),
    );

    return JitanModal(
      width: 760,
      title: context.t(AdminTextKeys.timeReviewTitle),
      subtitle: '${TimeRecordText.name(_day)} · ${TimeRecordText.longDate(context, _day.date)}',
      onClose: _busy != null ? null : _close,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: JitanColors.noteSurface, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(
                  value(AdminTextKeys.timeReviewDetected, _range((b) => _side(b)?.actualLocal), JitanColors.ink),
                  value(
                    AdminTextKeys.timeReviewRequested,
                    _range((b) => _pending(b)?.requestedLocal ?? _side(b)?.actualLocal),
                    JitanColors.info,
                  ),
                ),
                const SizedBox(height: 22),
                pair(
                  value(AdminTextKeys.timeReviewRegistered, registered, JitanColors.success),
                  _noPayrollChange
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: JitanStatusPill(label: context.t(AdminTextKeys.timeReviewNoChange)),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text(context.t(AdminTextKeys.timeReviewReason), style: muted),
                  const SizedBox(height: 8),
                  Text(reasons, style: JitanTextStyles.tableCell),
                ],
                const SizedBox(height: 18),
                TimeCorrectionNote(text: context.t(AdminTextKeys.timeReviewRule, args: {'range': registered})),
              ],
            ),
          ),
          if (_failure case final failure?) ...[const SizedBox(height: 16), TimeCorrectionMessage(failure: failure)],
        ],
      ),
      actions: [
        JitanSecondaryButton(
          label: context.t(AdminTextKeys.timeReviewReject),
          onPressed: _busy != null ? null : () => _decide(TimeCorrectionOutcome.rejected),
        ),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.timeReviewApprove),
          busy: _busy == TimeCorrectionOutcome.approved,
          onPressed: _busy != null ? null : () => _decide(TimeCorrectionOutcome.approved),
        ),
      ],
    );
  }
}
