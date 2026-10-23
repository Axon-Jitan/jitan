import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import 'period_controller.dart';
import 'period_text.dart';

/// "VIEW · This week ⌄" (Figma 48:2) with its menu (398:6).
class PeriodViewSelector extends StatelessWidget {
  const PeriodViewSelector({super.key, required this.view, required this.onSelected});

  final PeriodView view;
  final ValueChanged<PeriodView> onSelected;

  static String label(BuildContext context, PeriodView v) => context.t(switch (v) {
    PeriodView.day => EmployeeTextKeys.periodViewDay,
    PeriodView.week => EmployeeTextKeys.periodViewWeek,
    PeriodView.month => EmployeeTextKeys.periodViewMonth,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => PopupMenuButton<PeriodView>(
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
      color: JitanColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        for (final v in PeriodView.values)
          PopupMenuItem(
            value: v,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: v == view ? JitanColors.inputFill : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(label(context, v), style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontWeight: FontWeight.w400)),
            ),
          ),
      ],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
        decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t(EmployeeTextKeys.periodView), style: JitanMobileTextStyles.fieldLabel),
                  const SizedBox(height: 4),
                  Text(label(context, view), style: JitanMobileTextStyles.cardTitle),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: JitanColors.ink),
          ],
        ),
      ),
    ),
  );
}

/// The dark total card ("38h 30m · REGISTERED THIS WEEK", "5h 27m
/// registered so far · WORKING").
class PeriodTotalCard extends StatelessWidget {
  const PeriodTotalCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  static TextStyle big() => JitanMobileTextStyles.displayLarge.copyWith(fontSize: 32, color: JitanColors.warmWhite);
  static TextStyle small() => JitanMobileTextStyles.cardText.copyWith(color: JitanColors.sidebarText);
}

/// The light pill on the dark card ("WORKING", "COMPLETE").
class PeriodBadge extends StatelessWidget {
  const PeriodBadge({super.key, required this.label, this.color = JitanColors.ink});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(color: JitanColors.warmWhite, borderRadius: BorderRadius.circular(16)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: JitanMobileTextStyles.fieldLabel.copyWith(color: color)),
      ],
    ),
  );
}

/// The timeline of a day (Figma 35:57, 99:56): time, dot and line, title,
/// detail and reason.
class PeriodTimeline extends StatelessWidget {
  const PeriodTimeline({super.key, required this.events, this.pending = const []});

  final List<TimeRecordEvent> events;

  /// The day's corrections still waiting for HR.
  final List<TimeRecordPending> pending;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (i, e) in events.indexed)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 52, child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.atLocal, style: JitanMobileTextStyles.cardText.copyWith(color: JitanColors.ink, fontSize: 13)))),
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    Container(width: 11, height: 11, decoration: BoxDecoration(color: PeriodText.eventColor(e), shape: BoxShape.circle)),
                    if (i < events.length - 1) Expanded(child: Container(width: 1.5, color: JitanColors.inputBorder)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(PeriodText.eventTitle(context, e), style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14)),
                      if (PeriodText.eventDetail(context, e, {for (final p in pending) p.boundary}) case final detail?) ...[
                        const SizedBox(height: 3),
                        Text(detail, style: JitanMobileTextStyles.cardText),
                      ],
                      if (e.reason case final reason? when reason.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(reason, style: JitanMobileTextStyles.cardText.copyWith(fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// "Daily registered hours" (Figma 48:2): one bar per weekday.
class PeriodWeekChart extends StatelessWidget {
  const PeriodWeekChart({super.key, required this.days});

  final List<MyPeriodDay> days;

  @override
  Widget build(BuildContext context) {
    final most = days.fold<int>(0, (m, d) => [m, d.registeredMinutes ?? 0, d.plannedMinutes ?? 0].reduce((a, b) => a > b ? a : b));
    const height = 72.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: JitanColors.inputBorder)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                label: '${PeriodText.shortDay(context, d.date)}: ${PeriodText.hours(context, d.registeredMinutes ?? 0)}',
                child: Column(
                  children: [
                    SizedBox(
                      height: height,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: (d.registeredMinutes ?? 0) > 0 && most > 0
                            ? Container(
                                width: 20,
                                height: height * d.registeredMinutes! / most,
                                decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(6)),
                              )
                            : Container(width: 20, height: 1.5, color: JitanColors.inputBorder),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(context.t(CommonTextKeys.weekdayShort[d.date.weekday - 1]), style: JitanMobileTextStyles.cardText),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Daily records" (Figma 48:2): a row per day that is planned or has
/// registrations, with its registered time; a tap opens Day details.
class PeriodDayList extends StatelessWidget {
  const PeriodDayList({super.key, required this.days, required this.onOpen});

  final List<MyPeriodDay> days;
  final ValueChanged<MyPeriodDay> onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = [for (final d in days) if (d.plannedMinutes != null || d.day != null) d];
    if (shown.isEmpty) return Text(context.t(EmployeeTextKeys.periodWeekNone), style: JitanMobileTextStyles.body);
    return Container(
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: JitanColors.inputBorder)),
      child: Column(
        children: [
          for (final (i, d) in shown.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 18, endIndent: 18, color: JitanColors.inputBorder),
            InkWell(
              onTap: () => onOpen(d),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 13, 10, 13),
                child: Row(
                  children: [
                    Expanded(child: Text(PeriodText.shortDay(context, d.date), style: JitanMobileTextStyles.summary.copyWith(fontSize: 14))),
                    if (d.needsAttention && d.day != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(PeriodText.status(context, d.day!.status), style: JitanMobileTextStyles.fieldLabel.copyWith(color: JitanColors.warning)),
                      )
                    else
                      Text(
                        d.registeredMinutes == null ? '—' : PeriodText.hours(context, d.registeredMinutes!),
                        style: JitanMobileTextStyles.cardTitleSmall.copyWith(fontSize: 14),
                      ),
                    const SizedBox(width: 10),
                    const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The month grid (Figma 48:49): Monday first, a dot under each day —
/// green worked, grey planned, red needs attention — and today circled.
class PeriodMonthCalendar extends StatelessWidget {
  const PeriodMonthCalendar({super.key, required this.days, required this.today, required this.onOpen});

  final List<MyPeriodDay> days;
  final DateTime today;
  final ValueChanged<MyPeriodDay> onOpen;

  static Color? dotOf(MyPeriodDay d) => switch (d) {
    _ when d.needsAttention => JitanColors.vermilion,
    _ when (d.registeredMinutes ?? 0) > 0 => JitanColors.success,
    _ when d.plannedMinutes != null => JitanColors.radioBorder,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final lead = days.first.date.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (final d in days) _cell(context, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: JitanColors.inputBorder)),
      child: Column(
        children: [
          Row(
            children: [
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      context.t(CommonTextKeys.weekdayShort[w - 1]).characters.first,
                      style: JitanMobileTextStyles.fieldLabel,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < cells.length ~/ 7; row++)
            Row(children: [for (var c = 0; c < 7; c++) Expanded(child: SizedBox(height: 46, child: cells[row * 7 + c]))]),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, MyPeriodDay d) {
    final isToday = d.date == today;
    final dot = dotOf(d);
    return InkWell(
      onTap: () => onOpen(d),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 28,
            alignment: Alignment.center,
            decoration: isToday
                ? BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(9), border: Border.all(color: JitanColors.radioBorder))
                : null,
            child: Text('${d.date.day}', style: JitanMobileTextStyles.summary.copyWith(fontSize: 13)),
          ),
          const SizedBox(height: 3),
          Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

/// "● Worked ● Planned ● Needs attention ○ Today".
class PeriodLegend extends StatelessWidget {
  const PeriodLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color? fill, String key) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: fill == null ? Border.all(color: JitanColors.ink) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(context.t(key), style: JitanMobileTextStyles.cardText.copyWith(fontSize: 11)),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(JitanColors.success, EmployeeTextKeys.periodLegendWorked),
        item(JitanColors.radioBorder, EmployeeTextKeys.periodLegendPlanned),
        item(JitanColors.vermilion, EmployeeTextKeys.periodLegendAttention),
        item(null, EmployeeTextKeys.periodLegendToday),
      ],
    );
  }
}
