import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// One number of a report: its label, its value, its colour, and where a tap
/// on it leads (`null`: nowhere).
typedef ReportNumber = (String label, String value, Color color, VoidCallback? onTap);

/// One quiet card with a report's numbers side by side (Figma `1571:2`,
/// `1571:390`); two per row on a phone. A number that leads somewhere shows
/// a › after its value ("Days to review 26 ›" opens them in Time records).
class ReportNumbersCard extends StatelessWidget {
  const ReportNumbersCard({super.key, required this.numbers});

  final List<ReportNumber> numbers;

  @override
  Widget build(BuildContext context) {
    Widget item(ReportNumber value) {
      final (label, text, color, onTap) = value;
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanTextStyles.pageTitle.copyWith(fontSize: 26, color: color))),
                if (onTap != null) Icon(Icons.chevron_right_rounded, size: 24, color: color),
              ],
            ),
          ],
        ),
      );
      if (onTap == null) return content;
      return Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: content),
        ),
      );
    }

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
