import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_text.dart';

/// "The day's work" (Figma `1604:2`, `1604:85`, 2026-11-13): how the worked
/// time splits by kind, as its own card under the total, like Screen Time's
/// categories. One slim bar in one family of shades (amber only for other
/// work, which needs a look) and the numbers under it. Shown only with two
/// or more kinds of work; travel is never part of it (D46).
class HomeWorkCard extends StatelessWidget {
  const HomeWorkCard({super.key, required this.breakdown});

  final ActivityBreakdown breakdown;

  /// The parts with time in them, largest kind first as on the server.
  static List<(String, int, Color)> partsOf(ActivityBreakdown b) => [
    (EmployeeTextKeys.activityClientWork, b.clientMinutes, JitanColors.ink),
    (EmployeeTextKeys.activityInternal, b.internalMinutes, JitanColors.radioBorder),
    (EmployeeTextKeys.activityOtherWork, b.otherMinutes, JitanColors.warning),
  ].where((p) => p.$2 > 0).toList();

  /// Worth a card: two or more kinds of work.
  static bool shows(ActivityBreakdown b) => partsOf(b).length > 1;

  @override
  Widget build(BuildContext context) {
    final parts = partsOf(breakdown);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: JitanColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          // Fills from left to right when Home opens.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => ClipRect(
              child: Align(alignment: Alignment.centerLeft, widthFactor: t, child: child),
            ),
            child: Row(
              spacing: 2,
              children: [
                for (final (_, minutes, color) in parts)
                  Expanded(
                    flex: minutes,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              for (final (i, (key, minutes, _)) in parts.indexed)
                Flexible(
                  child: Column(
                    crossAxisAlignment: i == parts.length - 1 ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(context.t(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanMobileTextStyles.label),
                      Text(
                        TodayText.duration(context, minutes),
                        style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
