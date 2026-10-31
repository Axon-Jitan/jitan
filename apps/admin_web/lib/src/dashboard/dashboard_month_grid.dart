import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// One month, Monday first, with the chosen period marked. Always six rows,
/// so the picker keeps its height from month to month.
class DashboardMonthGrid extends StatelessWidget {
  const DashboardMonthGrid({
    super.key,
    required this.month,
    required this.from,
    required this.to,
    required this.today,
    required this.selectable,
    required this.onPick,
  });

  final DateTime month;
  final DateTime from;
  final DateTime to;
  final DateTime today;

  /// Whether a past or present day may be clicked now.
  final bool Function(DateTime day) selectable;
  final ValueChanged<DateTime> onPick;

  static const _rowHeight = 34.0;

  Widget _cell(DateTime? day) {
    if (day == null) return const SizedBox(height: _rowHeight);
    final last = DateTime(today.year, today.month, today.day);
    final enabled = !day.isAfter(last) && selectable(day);
    final isEnd = day == from || day == to;
    final inside = day.isAfter(from) && day.isBefore(to);
    final radius = BorderRadius.circular(10);
    final colour = isEnd
        ? JitanColors.surface
        : enabled
        ? JitanColors.ink
        : JitanColors.inputBorder;
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        color: inside ? JitanColors.dateRange : null,
        borderRadius: isEnd ? radius : null,
      ),
      child: Material(
        color: isEnd ? JitanColors.vermilion : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? () => onPick(day) : null,
          child: Center(
            child: Text(
              '${day.day}',
              style: JitanTextStyles.tableCell.copyWith(
                fontSize: 13,
                color: colour,
                fontWeight: isEnd ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blanks = DateTime(month.year, month.month).weekday - 1;
    final length = DateTime(month.year, month.month + 1, 0).day;
    final days = <DateTime?>[
      for (var i = 0; i < blanks; i++) null,
      for (var d = 1; d <= length; d++) DateTime(month.year, month.month, d),
    ];
    days.addAll(List.filled(42 - days.length, null));
    return Column(
      children: [
        Row(
          children: [
            for (final key in CommonTextKeys.weekdayShort)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    context.t(key).characters.first,
                    textAlign: TextAlign.center,
                    style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted),
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < 6; row++)
          Row(children: [for (final day in days.skip(row * 7).take(7)) Expanded(child: _cell(day))]),
      ],
    );
  }
}
