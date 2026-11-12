import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_correction_flow.dart';
import 'time_record_card.dart';
import 'time_record_popup.dart';
import 'time_record_text.dart';
import 'time_record_timeline.dart';

/// Opens a day. Returns the correction HR chose from it ("Correct time" or
/// "Review correction"), or `null` when HR only closed it.
Future<TimeCorrectionStep?> showTimeRecordDialog(BuildContext context, {required TimeRecordDay day, required bool mayCorrect}) =>
    showJitanModal<TimeCorrectionStep>(context, builder: (_) => TimeRecordDialog(day: day, mayCorrect: mayCorrect));

/// Figma `HR / Time records V2 — a day` (`1566:2`): the employee and the
/// day, the start and finish as registered (actual) and as they count
/// (rounded), with how each was registered; time away and travel (D34,
/// D46) when there is any; what happened, step by step; and "Correct time"
/// (or "Review correction" while the employee's correction waits, D31). A
/// time entered afterwards or corrected shows its reason (D30).
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
  Widget build(BuildContext context) => TimeRecordPopup(
    title: TimeRecordText.name(day),
    subtitle: context.t(
      AdminTextKeys.timeRecordDaySubtitle,
      args: {'date': TimeRecordText.dayDate(context, day.date), 'status': TimeRecordText.statusLine(context, day)},
    ),
    body: [
      TimeRecordCard(
        widths: const [110, 110],
        headings: [context.t(AdminTextKeys.timeRecordCardActual), context.t(AdminTextKeys.timeRecordCardRounded)],
        rows: [_time(context, RegistrationBoundary.start, day.start), _time(context, RegistrationBoundary.finish, day.finish)],
      ),
      if (day.awayMinutes > 0 || day.transportMinutes > 0) ...[
        const SizedBox(height: 12),
        TimeRecordCard(
          widths: const [110],
          rows: [
            if (day.awayMinutes > 0)
              TimeRecordCardRow(
                label: context.t(AdminTextKeys.timeRecordDayAway),
                detail: context.t(AdminTextKeys.timeRecordDayAwayText),
                values: [TimeRecordCard.value(_minutes(context, day.awayMinutes), strong: true)],
              ),
            if (day.transportMinutes > 0)
              TimeRecordCardRow(
                label: context.t(AdminTextKeys.timeRecordDayTransport),
                detail: _travelText(context, day),
                values: [TimeRecordCard.value(_minutes(context, day.transportMinutes), strong: true)],
              ),
          ],
        ),
      ],
      if (day.pending.isNotEmpty) ...[
        const SizedBox(height: 12),
        TimeRecordNotice(context.t(AdminTextKeys.timeRecordDayPending)),
      ] else if (day.nonWorkReason case final reason?) ...[
        const SizedBox(height: 12),
        TimeRecordNotice(context.t(AdminTextKeys.timeRecordDayNonWork, args: {'reason': reason}), warning: false),
      ],
      if (day.events.isNotEmpty) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _timeline = !_timeline),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 36)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Flexible(
                  child: Text(
                    context.t(_timeline ? AdminTextKeys.timeRecordDayTimelineHide : AdminTextKeys.timeRecordDayTimeline),
                    style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(_timeline ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: JitanColors.inkMuted),
              ],
            ),
          ),
        ),
        if (_timeline) TimeRecordTimeline(events: day.events),
      ],
    ],
    bottom: TimeRecordNote(context.t(AdminTextKeys.timeRecordDayNote)),
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

  /// The start or finish: as registered and as it counts, with how it was
  /// registered, or why it was entered afterwards or corrected.
  TimeRecordCardRow _time(BuildContext context, RegistrationBoundary boundary, TimeRecordTime? time) {
    final label = TimeRecordText.boundary(context, boundary);
    if (time == null) {
      return TimeRecordCardRow(
        label: label,
        detail: context.t(AdminTextKeys.timeRecordDayNotRegistered),
        detailColor: JitanColors.warning,
        values: [TimeRecordCard.value('—', muted: true), TimeRecordCard.value('—', muted: true)],
      );
    }
    final reason = time.reason;
    final detail = [
      TimeRecordText.method(context, time.method),
      if (time.correctedBy != null)
        context.t(AdminTextKeys.timeRecordDayCorrectedBy, args: {'reason': reason ?? ''})
      else if (time.enteredByHand)
        reason == null || reason.isEmpty
            ? context.t(AdminTextKeys.timeRecordDayEnteredAfterwards)
            : context.t(AdminTextKeys.timeRecordDayCorrected, args: {'reason': reason}),
      if (time.correctedBy != null && time.originalLocal != null)
        context.t(AdminTextKeys.timeRecordDayOriginal, args: {'time': time.originalLocal!}),
    ].join('\n');
    return TimeRecordCardRow(
      label: label,
      detail: detail.isEmpty ? null : detail,
      values: [TimeRecordCard.value(time.actualLocal), TimeRecordCard.value(time.roundedLocal ?? '—', strong: true)],
    );
  }

  static String _minutes(BuildContext context, int minutes) => context.t(
    AdminTextKeys.timeRecordDayAwayValue,
    args: {'hours': minutes ~/ 60, 'minutes': (minutes % 60).toString().padLeft(2, '0')},
  );

  /// "2 trips · 36 km · Shown next to worked time, not part of it" (D46);
  /// the distance leaves out trips without one.
  static String _travelText(BuildContext context, TimeRecordDay day) => [
    if (day.trips > 0) context.tPlural(AdminTextKeys.timeRecordDayTrips, day.trips),
    if (day.distanceMetres > 0) context.t(AdminTextKeys.reportKilometres, args: {'km': (day.distanceMetres / 1000).round()}),
    context.t(AdminTextKeys.timeRecordDayTravelText),
  ].join(' · ');
}
