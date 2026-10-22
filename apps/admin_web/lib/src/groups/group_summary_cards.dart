import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import '../schedules/schedule_summary_text.dart';
import 'group_hours_panel.dart';

/// The four cards under the group page's title (Figma `1455:2`):
/// employees, work hours, break and attendance. Four in a row on a wide
/// window, two by two on a tablet, one under the other on a phone.
class GroupSummaryCards extends StatelessWidget {
  const GroupSummaryCards({super.key, required this.memberCount, required this.needChoice, required this.schedule});

  final int memberCount;

  /// Members who still need HR's choice of group.
  final int needChoice;
  final GroupSchedule? schedule;

  @override
  Widget build(BuildContext context) {
    final t = TranslationScope.of(context);
    final variant = configuredVariant(schedule);
    final days = [
      for (final d in variant?.workDays ?? const <WorkDaySchedule>[])
        if (d.start != null && d.finish != null) d,
    ]..sort((a, b) => a.day.weekday.compareTo(b.day.weekday));
    final hours = {for (final d in days) '${d.start!.time}–${d.finish!.time}'};
    final breakMinutes = variant?.breaks.firstOrNull?.lengthMinutes;
    final first = days.firstOrNull;

    final cards = [
      _card(
        context.t(AdminTextKeys.groupDetailCardEmployees),
        '$memberCount',
        needChoice > 0
            ? context.tPlural(AdminTextKeys.groupDetailNeedChoice, needChoice)
            : variant == null || memberCount == 0
            ? null
            : context.t(AdminTextKeys.groupDetailAllSet),
        subColor: needChoice > 0 ? JitanColors.warning : null,
      ),
      if (variant == null || days.isEmpty)
        _card(
          context.t(AdminTextKeys.groupDetailCardHours),
          context.t(schedule?.status == GroupScheduleStatus.employeesDiffer ? AdminTextKeys.groupDetailHoursDiffer : AdminTextKeys.groupDetailNoHours),
          context.t(AdminTextKeys.groupDetailNoHoursText),
        )
      else
        _card(
          context.t(AdminTextKeys.groupDetailCardHours),
          dayListText(t, [for (final d in days) d.day.weekday]),
          hours.length == 1 ? hours.single : workHoursDaysSummary(t, variant),
        ),
      _card(
        context.t(AdminTextKeys.groupDetailCardBreak),
        breakMinutes == null
            ? context.t(variant == null ? AdminTextKeys.groupDetailNoHours : AdminTextKeys.groupDetailNoBreak)
            : context.t(AdminTextKeys.groupDetailBreakMinutes, args: {'minutes': breakMinutes}),
        breakMinutes == null ? null : context.t(AdminTextKeys.groupDetailBreakDeducted),
      ),
      _card(
        context.t(AdminTextKeys.groupDetailCardAttendance),
        first == null ? context.t(AdminTextKeys.groupDetailNoHours) : roundingPairText(t, first.start!.rounding, first.finish!.rounding),
        first == null
            ? null
            : first.start!.toleranceMinutes == first.finish!.toleranceMinutes
            ? context.t(AdminTextKeys.groupDetailTolerance, args: {'minutes': first.start!.toleranceMinutes})
            : context.t(
                AdminTextKeys.groupDetailToleranceSplit,
                args: {'arrival': first.start!.toleranceMinutes, 'leaving': first.finish!.toleranceMinutes},
              ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final perRow = constraints.maxWidth >= 1000 ? 4 : (constraints.maxWidth >= 520 ? 2 : 1);
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in cards) SizedBox(width: width, child: card)],
        );
      },
    );
  }

  static Widget _card(String label, String value, String? sub, {Color? subColor}) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: JitanTextStyles.tableHeader.copyWith(fontSize: 11, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanTextStyles.pageTitle.copyWith(fontSize: 24, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(
          sub ?? ' ',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: JitanTextStyles.stateMessage.copyWith(fontSize: 13, color: subColor),
        ),
      ],
    ),
  );
}
