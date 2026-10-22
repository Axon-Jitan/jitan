import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';

/// The group's one schedule, when its employees agree on one.
ScheduleVariant? configuredVariant(GroupSchedule? schedule) =>
    schedule?.status == GroupScheduleStatus.configured && schedule!.variants.length == 1 ? schedule.variants.single : null;

/// "Work hours & break" on the group page (Figma `1455:2`): every weekday
/// with its hours or "Day off", then break, tolerance and rounding, and the
/// button that opens the schedule wizard on this group.
class GroupHoursPanel extends StatelessWidget {
  const GroupHoursPanel({super.key, required this.schedule, required this.hasMembers, required this.onEdit});

  final GroupSchedule? schedule;
  final bool hasMembers;

  /// `null` while the group is inactive.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final variant = configuredVariant(schedule);
    final muted = JitanTextStyles.stateMessage.copyWith(fontSize: 13);
    final strong = JitanTextStyles.tableCellStrong.copyWith(fontSize: 13);

    Widget line(String label, String value, {bool dim = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: dim ? JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted) : JitanTextStyles.tableCell)),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: dim ? JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted) : JitanTextStyles.tableCellStrong,
              ),
            ),
          ),
        ],
      ),
    );

    final List<Widget> content;
    if (variant == null) {
      content = [
        Text(
          context.t(switch (schedule?.status) {
            GroupScheduleStatus.employeesDiffer => AdminTextKeys.groupDetailHoursDifferText,
            GroupScheduleStatus.noSingleGroupEmployees when hasMembers => AdminTextKeys.groupDetailHoursNoSingleText,
            _ => AdminTextKeys.groupDetailHoursEmptyText,
          }),
          style: JitanTextStyles.stateMessage,
        ),
      ];
    } else {
      final days = {for (final d in variant.workDays) if (d.start != null && d.finish != null) d.day.weekday: d};
      final first = days.values.firstOrNull;
      final breakMinutes = variant.breaks.firstOrNull?.lengthMinutes;
      content = [
        for (var weekday = 1; weekday <= 7; weekday++)
          switch (days[weekday]) {
            final day? => line(context.t(AdminTextKeys.weekdayLong[weekday - 1]), '${day.start!.time}–${day.finish!.time}'),
            null => line(context.t(AdminTextKeys.weekdayLong[weekday - 1]), context.t(AdminTextKeys.groupDetailDayOff), dim: true),
          },
        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: JitanColors.inputBorder)),
        _detail(
          context.t(AdminTextKeys.groupDetailBreakRow),
          breakMinutes == null
              ? context.t(AdminTextKeys.groupDetailNoBreak)
              : context.t(AdminTextKeys.groupDetailBreakValue, args: {'minutes': breakMinutes}),
          muted,
          strong,
        ),
        if (first != null) ...[
          _detail(
            context.t(AdminTextKeys.groupDetailToleranceRow),
            context.t(
              AdminTextKeys.groupDetailToleranceValue,
              args: {'arrival': first.start!.toleranceMinutes, 'leaving': first.finish!.toleranceMinutes},
            ),
            muted,
            strong,
          ),
          _detail(
            context.t(AdminTextKeys.groupDetailRoundingRow),
            roundingPairText(t, first.start!.rounding, first.finish!.rounding),
            muted,
            strong,
          ),
        ],
      ];
    }

    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t(AdminTextKeys.groupDetailHoursPanel), style: JitanTextStyles.stateTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 14),
          ...content,
          const SizedBox(height: 18),
          JitanPrimaryButton(
            label: context.t(variant != null || schedule?.status == GroupScheduleStatus.employeesDiffer
                ? AdminTextKeys.groupPageEditHours
                : AdminTextKeys.groupPageSetHours),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  static Widget _detail(String label, String value, TextStyle muted, TextStyle strong) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: muted)),
        const SizedBox(width: 12),
        Flexible(child: Align(alignment: Alignment.centerRight, child: Text(value, textAlign: TextAlign.end, style: strong))),
      ],
    ),
  );
}

/// "No rounding" when neither boundary rounds or both round alike;
/// otherwise "Start Up · 15 min · finish No rounding".
String roundingPairText(Translations t, ScheduleRounding? start, ScheduleRounding? finish) {
  final s = roundingText(t, start), f = roundingText(t, finish);
  return s == f ? s : t.t(AdminTextKeys.groupDetailRoundingValue, args: {'start': s, 'finish': f});
}
