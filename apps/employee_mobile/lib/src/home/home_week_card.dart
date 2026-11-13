import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../period/period_text.dart';
import '../widgets/phone_widgets.dart';

/// "This week" on Home (Figma `1606:2`, 2026-11-13): the week's registered
/// time against its plan, with a tiny bar per day, the same numbers as
/// Period's week. A tap opens Period on the week.
class HomeWeekCard extends StatelessWidget {
  const HomeWeekCard({super.key, required this.week, required this.today, required this.onOpen});

  final MyPeriod week;
  final DateTime today;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final planned = week.plannedMinutes;
    const height = 56.0;
    return Material(
      color: JitanColors.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Row(
                children: [
                  Expanded(child: Text(context.t(EmployeeTextKeys.todayThisWeek), style: JitanMobileTextStyles.label)),
                  const PhoneChevron(),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 6,
                children: [
                  Text(
                    PeriodText.duration(context, week.registeredMinutes),
                    style: JitanMobileTextStyles.pageTitle.copyWith(fontSize: 22, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  if (planned > 0)
                    Text(
                      context.t(EmployeeTextKeys.todayWeekOf, args: {'hours': PeriodText.hours(context, planned)}),
                      style: JitanMobileTextStyles.detail,
                    ),
                ],
              ),
              _days(context, height),
            ],
          ),
        ),
      ),
    );
  }

  /// A tiny bar per day: registered time in ink, today while it runs in grey.
  Widget _days(BuildContext context, double height) {
    final most = week.days.fold<int>(0, (m, d) => [m, d.registeredMinutes ?? 0, d.plannedMinutes ?? 0].reduce((a, b) => a > b ? a : b));
    return Row(
      children: [
        for (final d in week.days)
          Expanded(
            child: Column(
              spacing: 6,
              children: [
                SizedBox(
                  height: height,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 8,
                      height: (d.registeredMinutes ?? 0) > 0 && most > 0 ? (height * d.registeredMinutes! / most).clamp(4, height) : 2,
                      decoration: BoxDecoration(
                        color: (d.registeredMinutes ?? 0) > 0
                            ? (d.date == today ? JitanColors.radioBorder : JitanColors.ink)
                            : JitanColors.inputBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                Text(
                  context.t(CommonTextKeys.weekdayShort[d.date.weekday - 1]).characters.first,
                  style: JitanMobileTextStyles.detail.copyWith(
                    fontSize: 11,
                    color: d.date == today ? JitanColors.ink : JitanColors.inkMuted,
                    fontWeight: d.date == today ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
