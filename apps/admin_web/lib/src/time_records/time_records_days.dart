import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';
import 'attendance_mark.dart';
import 'time_correction_flow.dart';
import 'time_record_text.dart';

/// Time records grouped by day (Figma `HR / Time records V2 — page`
/// `1565:2`): the column names once, then each day under its heading
/// ("Today · Thursday 12 November", "5 to review") as one white card. A row
/// opens the day, or straight what HR has to do: **Fix** a missing start,
/// finish or registration, **Review** an employee's correction (D31). Rows
/// with nothing to do show a › while hovered. A phone keeps the employee
/// and the status.
///
/// A day still in progress says **Working** (product owner, 2026-10-22).
class TimeRecordsDays extends StatelessWidget {
  const TimeRecordsDays({super.key, required this.days, required this.today, required this.actionOf, required this.onOpen});

  /// In the server's order: newest day first.
  final List<TimeRecordDay> days;
  final DateTime today;

  /// What the row offers: Fix, Review, or `null` (it opens the day).
  final TimeCorrectionStep? Function(TimeRecordDay day) actionOf;
  final ValueChanged<TimeRecordDay> onOpen;

  /// As Figma (300 / 170 / 170 / 140 / 210, the action in the rest).
  static const _flex = [300, 170, 170, 140, 210, 90];
  static const _flexPhone = [190, 150, 60];

  static const _radius = Radius.circular(16);

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<TimeRecordDay>>{};
    for (final day in days) {
      groups.putIfAbsent(day.date, () => []).add(day);
    }
    final items = <Object>[];
    for (final MapEntry(key: date, value: rows) in groups.entries) {
      items.add((date, rows));
      for (final (i, day) in rows.indexed) {
        items.add(_Row(day, first: i == 0, last: i == rows.length - 1));
      }
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.crossAxisExtent < JitanDimensions.phoneBreakpoint;
        return SliverList.builder(
          itemCount: items.length + 1,
          itemBuilder: (context, i) => switch (i == 0 ? null : items[i - 1]) {
            null => _columns(context, phone),
            (final DateTime date, final List<TimeRecordDay> rows) => _heading(context, date, rows, first: i == 1),
            final _Row row => _row(context, row, phone),
            _ => const SizedBox.shrink(),
          },
        );
      },
    );
  }

  Widget _cells(List<Widget> cells, bool phone) {
    final flex = phone ? _flexPhone : _flex;
    return Row(
      children: [
        for (final (i, cell) in cells.indexed)
          Expanded(flex: flex[i], child: Align(alignment: i == cells.length - 1 ? Alignment.centerRight : Alignment.centerLeft, child: cell)),
      ],
    );
  }

  Widget _columns(BuildContext context, bool phone) {
    final style = JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted, fontWeight: FontWeight.w500);
    Text label(String key) => Text(context.t(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: _cells([
        label(AdminTextKeys.timeRecordsColumnEmployee),
        if (!phone) ...[
          label(AdminTextKeys.timeRecordsColumnRounded),
          label(AdminTextKeys.timeRecordsColumnActual),
          label(AdminTextKeys.timeRecordsColumnMethod),
        ],
        label(AdminTextKeys.timeRecordsColumnStatus),
        const SizedBox.shrink(),
      ], phone),
    );
  }

  Widget _heading(BuildContext context, DateTime date, List<TimeRecordDay> rows, {required bool first}) {
    final (label, dateText) = TimeRecordText.dayHeading(context, date, today);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, first ? 18 : 26, 4, 10),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 8,
          children: [
            Text(label, style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 15)),
            Expanded(
              child: Text(
                dateText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: JitanTextStyles.tableCell.copyWith(fontSize: 15, color: JitanColors.inkMuted),
              ),
            ),
            // At the right end, at most half the line on a narrow screen.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: Text(
                TimeRecordText.daySummary(context, rows),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, _Row row, bool phone) {
    final day = row.day;
    final action = actionOf(day);
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    final open = day.status == TimeRecordStatus.working;
    final rounded = TimeRecordText.range(day.start?.roundedLocal, day.finish?.roundedLocal, open: open);
    final method = day.start?.method ?? day.finish?.method;
    Text text(String value, TextStyle style) => Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final cells = [
      text(TimeRecordText.name(day), JitanTextStyles.tableCellStrong),
      if (!phone) ...[
        text(rounded, rounded == '—' ? muted : JitanTextStyles.tableCell),
        text(TimeRecordText.range(day.start?.actualLocal, day.finish?.actualLocal, open: open), muted),
        text(method == null ? '—' : TimeRecordText.method(context, method), muted),
      ],
      Row(
        spacing: 8,
        children: [
          Flexible(
            child: JitanStatusLabel(
              label: TimeRecordText.status(context, day.status),
              isPositive: day.status == TimeRecordStatus.complete,
              color: TimeRecordText.statusColor(day.status),
            ),
          ),
          // On time needs no mark: only what HR should notice.
          if (!phone)
            if (day.attendance case final attendance? when attendance != DayAttendance.onTime) AttendanceMark(attendance: attendance),
        ],
      ),
      if (action == null)
        const SizedBox.shrink()
      else
        text(
          context.t(action == TimeCorrectionStep.review ? AdminTextKeys.timeRecordsReview : AdminTextKeys.timeRecordsFix),
          JitanTextStyles.tableCellStrong.copyWith(color: JitanColors.vermilion),
        ),
    ];
    final radius = BorderRadius.only(
      topLeft: row.first ? _radius : Radius.zero,
      topRight: row.first ? _radius : Radius.zero,
      bottomLeft: row.last ? _radius : Radius.zero,
      bottomRight: row.last ? _radius : Radius.zero,
    );
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: JitanColors.surface,
        child: JitanTappableRow(
          onTap: () => onOpen(day),
          hoverChevron: action == null,
          child: Column(
            children: [
              if (!row.first)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 1, thickness: 1, color: JitanColors.cardBorder),
                ),
              SizedBox(
                height: 48,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _cells(cells, phone)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.day, {required this.first, required this.last});

  final TimeRecordDay day;
  final bool first;
  final bool last;
}
