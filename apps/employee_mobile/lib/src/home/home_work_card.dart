import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import '../today/today_text.dart';

/// "The day's work" (Figma `1604:2`, `1604:85`, `1606:128`, 2026-11-13): how
/// the worked time splits, as its own card under the total, like Screen
/// Time's categories. By kind of work when there are two or more kinds
/// (columns of numbers, amber only for other work); otherwise by project when
/// the day went to two or more projects (rows: the name and its time).
/// Nothing when the split says nothing new. Travel is never part of it (D46).
class HomeWorkCard extends StatelessWidget {
  const HomeWorkCard({super.key, required this.breakdown});

  final ActivityBreakdown breakdown;

  /// Projects past the third share one grey part.
  static const _shownProjects = 3;

  /// The kinds with time in them.
  static List<(String, int, Color)> kindsOf(ActivityBreakdown b) => [
    (EmployeeTextKeys.activityClientWork, b.clientMinutes, JitanColors.ink),
    (EmployeeTextKeys.activityInternal, b.internalMinutes, JitanColors.radioBorder),
    (EmployeeTextKeys.activityOtherWork, b.otherMinutes, JitanColors.warning),
  ].where((p) => p.$2 > 0).toList();

  /// Worth a card: two or more kinds of work, or two or more projects.
  static bool shows(ActivityBreakdown b) => kindsOf(b).length > 1 || b.projects.length > 1;

  @override
  Widget build(BuildContext context) {
    final kinds = kindsOf(breakdown);
    final byKind = kinds.length > 1;
    final segments = byKind ? [for (final (_, minutes, color) in kinds) (minutes, color)] : _projectSegments();
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
                for (final (minutes, color) in segments)
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
          if (byKind) _kindColumns(context, kinds) else _projectRows(context),
        ],
      ),
    );
  }

  /// "Client work 3h 05m … Internal work 1h 13m", spread across the card.
  Widget _kindColumns(BuildContext context, List<(String, int, Color)> kinds) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      for (final (i, (key, minutes, _)) in kinds.indexed)
        Flexible(
          child: Column(
            crossAxisAlignment: i == kinds.length - 1 ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(context.t(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanMobileTextStyles.label),
              Text(TodayText.duration(context, minutes), style: _number),
            ],
          ),
        ),
    ],
  );

  /// The projects, most time first; a fourth and later share one line.
  List<(String, int)> _projectLines(BuildContext context) {
    final projects = breakdown.projects;
    if (projects.length <= _shownProjects) return [for (final p in projects) (p.name, p.minutes)];
    final rest = projects.skip(_shownProjects - 1).fold(0, (sum, p) => sum + p.minutes);
    return [
      for (final p in projects.take(_shownProjects - 1)) (p.name, p.minutes),
      (context.t(EmployeeTextKeys.activityOtherProjects), rest),
    ];
  }

  /// One family of shades: ink, then lighter greys.
  List<(int, Color)> _projectSegments() {
    const shades = [JitanColors.ink, JitanColors.radioBorder, JitanColors.radioIdle];
    final projects = breakdown.projects;
    final shown = projects.length <= _shownProjects
        ? [for (final p in projects) p.minutes]
        : [
            for (final p in projects.take(_shownProjects - 1)) p.minutes,
            projects.skip(_shownProjects - 1).fold(0, (sum, p) => sum + p.minutes),
          ];
    return [for (final (i, minutes) in shown.indexed) (minutes, shades[i])];
  }

  /// "P-0990 Clean the workshop · 3h 10m", in the bar's order.
  Widget _projectRows(BuildContext context) => Column(
    spacing: 8,
    children: [
      for (final (name, minutes) in _projectLines(context))
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: JitanMobileTextStyles.rowText),
            ),
            Text(TodayText.duration(context, minutes), style: _number.copyWith(fontSize: 15)),
          ],
        ),
    ],
  );

  static final _number = JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17, fontFeatures: const [FontFeature.tabularFigures()]);
}
