import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'time_record_text.dart';

Future<void> showTimeRecordDialog(BuildContext context, {required TimeRecordDay day}) =>
    showJitanModal<void>(context, builder: (_) => TimeRecordDialog(day: day));

/// Figma `HR / Time records — Day detail modal` (160:94): the day's start
/// and finish, each with its actual registration and its rounded time.
///
/// Not shown yet: "Correct time" (HR corrections, the next slice) and the
/// detailed timeline (its absences and workplaces need geofencing). A time
/// entered afterwards shows its reason, which HR needs to judge it (D30).
class TimeRecordDialog extends StatelessWidget {
  const TimeRecordDialog({super.key, required this.day});

  final TimeRecordDay day;

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
            if (time.enteredByHand) ...[
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
