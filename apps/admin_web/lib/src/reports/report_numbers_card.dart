import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// One number of a report: its label, its value, and its colour.
typedef ReportNumber = (String label, String value, Color color);

/// One quiet card with a report's numbers side by side (Figma `1508:234`,
/// `1515:2`); two per row on a phone (`1482:2`).
class ReportNumbersCard extends StatelessWidget {
  const ReportNumbersCard({super.key, required this.numbers});

  final List<ReportNumber> numbers;

  @override
  Widget build(BuildContext context) {
    Widget item(ReportNumber value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value.$1, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value.$2, style: JitanTextStyles.pageTitle.copyWith(fontSize: 26, color: value.$3)),
        ],
      ),
    );
    return JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < JitanDimensions.phoneBreakpoint
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    // Two per row; an odd last one keeps its column's width.
                    for (var i = 0; i < numbers.length; i += 2)
                      Row(
                        children: [
                          Expanded(child: item(numbers[i])),
                          Expanded(child: i + 1 < numbers.length ? item(numbers[i + 1]) : const SizedBox.shrink()),
                        ],
                      ),
                  ],
                )
              : IntrinsicHeight(
                  child: Row(
                    children: [
                      for (final (i, value) in numbers.indexed) ...[
                        if (i > 0) const VerticalDivider(width: 1, color: JitanColors.inputBorder),
                        Expanded(child: item(value)),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
