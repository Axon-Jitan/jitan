import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../widgets/phone_widgets.dart';
import 'period_controller.dart';
import 'period_stamps.dart';
import 'period_text.dart';

// The pieces of Period in the calm phone style (Figma `1595:577`,
// 2026-11-13).

/// Day | Week | Month, as an iOS segmented control.
class PeriodViewSwitch extends StatelessWidget {
  const PeriodViewSwitch({super.key, required this.view, required this.onSelected});

  final PeriodView view;
  final ValueChanged<PeriodView> onSelected;

  static String label(BuildContext context, PeriodView v) => context.t(switch (v) {
    PeriodView.day => EmployeeTextKeys.periodViewDay,
    PeriodView.week => EmployeeTextKeys.periodViewWeek,
    PeriodView.month => EmployeeTextKeys.periodViewMonth,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
    child: Row(
      spacing: 2,
      children: [
        for (final v in PeriodView.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: v == view,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == view ? JitanColors.surface : null,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: v == view ? const [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(
                    label(context, v),
                    style: JitanMobileTextStyles.rowTitle.copyWith(
                      fontSize: 14,
                      fontWeight: v == view ? FontWeight.w600 : FontWeight.w500,
                      color: v == view ? JitanColors.ink : JitanColors.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Two totals side by side ("Registered 15h 30m · Planned 176h").
class PeriodPairCard extends StatelessWidget {
  const PeriodPairCard({super.key, required this.items});

  final List<(String label, String value)> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(20)),
    child: Row(
      spacing: 16,
      children: [
        for (final (label, value) in items)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(label, style: JitanMobileTextStyles.label),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: JitanMobileTextStyles.hero.copyWith(fontSize: 34, letterSpacing: -1)),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// A day's timeline with its stamps: the time, a dot on a line, the title
/// and how or where under it (Figma `1595:362`).
class PeriodTimeline extends StatelessWidget {
  const PeriodTimeline({super.key, required this.stamps});

  final List<PeriodStamp> stamps;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.t(EmployeeTextKeys.periodTimelineLabel), style: JitanMobileTextStyles.label),
      const SizedBox(height: 12),
      for (final (i, stamp) in stamps.indexed) _stamp(stamp, last: i == stamps.length - 1),
    ],
  );

  Widget _stamp(PeriodStamp stamp, {required bool last}) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              stamp.time,
              style: JitanMobileTextStyles.rowText.copyWith(
                fontSize: 14,
                color: stamp.isPause ? JitanColors.inkMuted : JitanColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Column(
            children: [
              const SizedBox(height: 6),
              _dot(stamp.dot),
              if (!last) Expanded(child: Container(width: 1.5, color: JitanColors.inputBorder)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 10, bottom: last ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Text(
                  stamp.title,
                  style: stamp.isPause
                      ? JitanMobileTextStyles.rowTitle.copyWith(fontWeight: FontWeight.w500, color: JitanColors.inkMuted)
                      : JitanMobileTextStyles.rowTitle,
                ),
                if (stamp.detail case final detail?)
                  Text(
                    detail,
                    style: JitanMobileTextStyles.detail.copyWith(
                      color: stamp.detailColor,
                      fontWeight: stamp.detailColor == null ? null : FontWeight.w500,
                    ),
                  ),
                if (stamp.reason case final reason?) Text('“$reason”', style: JitanMobileTextStyles.detail),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  static Widget _dot(StampDot dot) {
    final (size, color) = switch (dot) {
      StampDot.start => (10.0, JitanColors.vermilion),
      StampDot.finish => (10.0, JitanColors.success),
      StampDot.activity => (8.0, JitanColors.ink),
      StampDot.waiting => (10.0, JitanColors.warning),
      StampDot.confirmed => (10.0, JitanColors.info),
      StampDot.quiet => (10.0, JitanColors.radioBorder),
      StampDot.pause => (10.0, JitanColors.warmWhite),
    };
    return SizedBox(
      height: 10,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: dot == StampDot.pause ? Border.all(color: JitanColors.radioBorder, width: 1.5) : null,
          ),
        ),
      ),
    );
  }
}

/// One bar per weekday (Figma `1595:54`): registered time in ink, today
/// while it runs in grey, nothing as a thin line.
class PeriodWeekChart extends StatelessWidget {
  const PeriodWeekChart({super.key, required this.days, required this.today});

  final List<MyPeriodDay> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final most = days.fold<int>(0, (m, d) => [m, d.registeredMinutes ?? 0, d.plannedMinutes ?? 0].reduce((a, b) => a > b ? a : b));
    const height = 76.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                label: '${PeriodText.shortDay(context, d.date)}: ${PeriodText.hours(context, d.registeredMinutes ?? 0)}',
                child: Column(
                  spacing: 8,
                  children: [
                    SizedBox(
                      height: height,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: (d.registeredMinutes ?? 0) > 0 && most > 0
                            ? Container(
                                width: 20,
                                height: height * d.registeredMinutes! / most,
                                decoration: BoxDecoration(
                                  color: d.date == today ? JitanColors.radioBorder : JitanColors.ink,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              )
                            : Container(width: 20, height: 2, color: JitanColors.inputBorder),
                      ),
                    ),
                    Text(
                      context.t(CommonTextKeys.weekdayShort[d.date.weekday - 1]),
                      style: JitanMobileTextStyles.detail.copyWith(
                        fontSize: 12,
                        color: d.date == today ? JitanColors.ink : JitanColors.inkMuted,
                        fontWeight: d.date == today ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The week's days as a white list: registered time, or what the day needs
/// in amber; a tap opens the day.
class PeriodDayList extends StatelessWidget {
  const PeriodDayList({super.key, required this.days, required this.onOpen});

  final List<MyPeriodDay> days;
  final ValueChanged<MyPeriodDay> onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final d in days)
        if (d.plannedMinutes != null || d.day != null) d,
    ];
    if (shown.isEmpty) return Text(context.t(EmployeeTextKeys.periodWeekNone), style: JitanMobileTextStyles.pageSubtitle);
    return PhoneListCard(
      padding: EdgeInsets.zero,
      children: [
        for (final d in shown)
          PhoneListRow(
            title: PeriodText.shortDay(context, d.date),
            titleStyle: JitanMobileTextStyles.rowText,
            onTap: () => onOpen(d),
            trailing: ConstrainedBox(
              // Room for the day on a small phone; a long value ends in "…".
              constraints: const BoxConstraints(maxWidth: 160),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Flexible(
                    child: Text(
                      PeriodText.dayValue(context, d),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JitanMobileTextStyles.rowText.copyWith(
                        color: d.needsAttention ? JitanColors.warning : null,
                        fontWeight: d.needsAttention ? FontWeight.w500 : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const PhoneChevron(),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The month (Figma `1595:152`): Monday first, today a dark circle,
/// weekends lighter, and a dot under each day: dark worked, amber needs
/// you, grey planned.
class PeriodMonthCalendar extends StatelessWidget {
  const PeriodMonthCalendar({super.key, required this.days, required this.today, required this.onOpen});

  final List<MyPeriodDay> days;
  final DateTime today;
  final ValueChanged<MyPeriodDay> onOpen;

  static Color? dotOf(MyPeriodDay d) => switch (d) {
    _ when d.needsAttention => JitanColors.warning,
    _ when (d.registeredMinutes ?? 0) > 0 => JitanColors.ink,
    _ when d.plannedMinutes != null => JitanColors.radioIdle,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final lead = days.first.date.weekday - 1;
    final cells = <Widget>[for (var i = 0; i < lead; i++) const SizedBox.shrink(), for (final d in days) _cell(context, d)];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            children: [
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      context.t(CommonTextKeys.weekdayShort[w - 1]).characters.first,
                      style: JitanMobileTextStyles.label.copyWith(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < cells.length ~/ 7; row++)
            Row(
              children: [for (var c = 0; c < 7; c++) Expanded(child: SizedBox(height: 46, child: cells[row * 7 + c]))],
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, MyPeriodDay d) {
    final isToday = d.date == today;
    final weekend = d.date.weekday >= DateTime.saturday;
    final dot = dotOf(d);
    return InkWell(
      onTap: () => onOpen(d),
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 3,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: isToday ? const BoxDecoration(color: JitanColors.ink, shape: BoxShape.circle) : null,
            child: Text(
              '${d.date.day}',
              style: JitanMobileTextStyles.rowText.copyWith(
                color: isToday ? JitanColors.surface : (weekend ? JitanColors.radioBorder : JitanColors.ink),
                fontWeight: isToday ? FontWeight.w600 : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// "● Worked ● Needs you ● Planned".
class PeriodLegend extends StatelessWidget {
  const PeriodLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color fill, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        ),
        Text(context.t(key), style: JitanMobileTextStyles.detail.copyWith(fontSize: 12)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(JitanColors.ink, EmployeeTextKeys.periodLegendWorked),
        item(JitanColors.warning, EmployeeTextKeys.periodLegendAttention),
        item(JitanColors.radioIdle, EmployeeTextKeys.periodLegendPlanned),
      ],
    );
  }
}

/// The grey shapes while a period loads: the total card and a list.
class PeriodSkeleton extends StatelessWidget {
  const PeriodSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block(double height, double radius) => Container(
      height: height,
      decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(radius)),
    );
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [block(141, 20), block(160, 18)]),
    );
  }
}
