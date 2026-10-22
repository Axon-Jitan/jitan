import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_correction_flow.dart';
import 'time_record_text.dart';
import 'time_record_timeline.dart';

/// Opens the day detail. Returns the correction HR chose from it ("Correct
/// time" or "Review correction"), or `null` when HR only closed it.
Future<TimeCorrectionStep?> showTimeRecordDialog(BuildContext context, {required TimeRecordDay day, required bool mayCorrect}) =>
    showJitanModal<TimeCorrectionStep>(context, builder: (_) => TimeRecordDialog(day: day, mayCorrect: mayCorrect));

/// Figma `HR / Time records — Day detail modal` (160:94): the day's start
/// and finish, each with its actual registration and its rounded time, the
/// detailed registration timeline, and "Correct time" (or "Review
/// correction" while the employee's correction waits, D31).
///
/// A time entered afterwards or corrected shows its reason, which HR needs to
/// judge it (D30). The timeline holds registrations and corrections; absences
/// and workplaces come with geofencing.
class TimeRecordDialog extends StatefulWidget {
  const TimeRecordDialog({super.key, required this.day, required this.mayCorrect});

  final TimeRecordDay day;

  /// `false` hides the correction button (no company to correct it in).
  final bool mayCorrect;

  @override
  State<TimeRecordDialog> createState() => _TimeRecordDialogState();
}

class _TimeRecordDialogState extends State<TimeRecordDialog> {
  bool _timeline = false;

  TimeRecordDay get day => widget.day;

  @override
  Widget build(BuildContext context) => JitanModal(
    width: 640,
    title: context.t(AdminTextKeys.timeRecordDayTitle),
    subtitle: context.t(
      AdminTextKeys.timeRecordDaySubtitle,
      args: {'name': TimeRecordText.name(day), 'date': TimeRecordText.longDate(context, day.date)},
    ),
    onClose: () => Navigator.of(context).pop(),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(context.t(AdminTextKeys.timeRecordDayDetails), style: JitanTextStyles.stateTitle),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final start = _card(context, Icons.subdirectory_arrow_right, AdminTextKeys.timeRecordDayStart, day.start);
            final finish = _card(context, Icons.turn_right, AdminTextKeys.timeRecordDayFinish, day.finish);
            return constraints.maxWidth < 480
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [start, const SizedBox(height: 14), finish])
                : IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [Expanded(child: start), const SizedBox(width: 20), Expanded(child: finish)],
                    ),
                  );
          },
        ),
        if (day.pending.isNotEmpty || day.nonWorkReason != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: day.pending.isNotEmpty ? JitanColors.warningSurface : JitanColors.noteSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              day.pending.isNotEmpty
                  ? context.t(AdminTextKeys.timeRecordDayPending)
                  : context.t(AdminTextKeys.timeRecordDayNonWork, args: {'reason': day.nonWorkReason!}),
              style: JitanTextStyles.stateMessage.copyWith(
                fontSize: 13,
                color: day.pending.isNotEmpty ? JitanColors.warning : JitanColors.ink,
              ),
            ),
          ),
        ],
        if (day.events.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _timeline = !_timeline),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 36)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      context.t(_timeline ? AdminTextKeys.timeRecordDayTimelineHide : AdminTextKeys.timeRecordDayTimeline),
                      style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_timeline ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 18, color: JitanColors.ink),
                ],
              ),
            ),
          ),
          if (_timeline) TimeRecordTimeline(events: day.events),
        ],
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 14, color: JitanColors.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.t(AdminTextKeys.timeRecordDayNote), style: JitanTextStyles.stateMessage.copyWith(fontSize: 13)),
            ),
          ],
        ),
      ],
    ),
    actions: [
      JitanSecondaryButton(label: context.t(AdminTextKeys.timeRecordDayClose), onPressed: () => Navigator.of(context).pop()),
      if (widget.mayCorrect)
        day.pending.isNotEmpty
            ? JitanPrimaryButton(
                label: context.t(AdminTextKeys.timeRecordDayReview),
                onPressed: () => Navigator.of(context).pop(TimeCorrectionStep.review),
              )
            : JitanPrimaryButton(
                label: context.t(AdminTextKeys.timeRecordDayCorrectTime),
                onPressed: () => Navigator.of(context).pop(TimeCorrectionStep.correct),
              ),
    ],
  );

  Widget _card(BuildContext context, IconData icon, String titleKey, TimeRecordTime? time) {
    final muted = JitanTextStyles.stateMessage.copyWith(fontSize: 12);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: JitanColors.ink),
              const SizedBox(width: 8),
              Text(context.t(titleKey), style: JitanTextStyles.tableCellStrong),
            ],
          ),
          const SizedBox(height: 18),
          Text(context.t(AdminTextKeys.timeRecordDayActual), style: muted),
          const SizedBox(height: 4),
          Text(
            time?.actualLocal ?? context.t(AdminTextKeys.timeRecordDayNotRegistered),
            style: time == null
                ? JitanTextStyles.stateTitle.copyWith(color: JitanColors.warning)
                : JitanTextStyles.pageTitle.copyWith(fontSize: 26),
          ),
          if (time != null) ...[
            if (time.correctedBy != null) ...[
              const SizedBox(height: 6),
              Text(context.t(AdminTextKeys.timeRecordDayCorrectedBy, args: {'reason': time.reason ?? ''}), style: muted),
              if (time.originalLocal case final original?) ...[
                const SizedBox(height: 2),
                Text(context.t(AdminTextKeys.timeRecordDayOriginal, args: {'time': original}), style: muted),
              ],
            ] else if (time.enteredByHand) ...[
              const SizedBox(height: 6),
              Text(
                time.reason == null || time.reason!.isEmpty
                    ? context.t(AdminTextKeys.timeRecordDayEnteredAfterwards)
                    : context.t(AdminTextKeys.timeRecordDayCorrected, args: {'reason': time.reason!}),
                style: muted,
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1, color: JitanColors.inputBorder),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(context.t(AdminTextKeys.timeRecordDayRounded), style: muted)),
                Text(time.roundedLocal ?? '—', style: JitanTextStyles.tableCellStrong),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
