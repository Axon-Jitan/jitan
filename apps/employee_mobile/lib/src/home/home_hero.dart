import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// Home's main card (Figma `1585:2`): a quiet label, one big value and short
/// lines under it. Dark while the day runs, white otherwise.
class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.label,
    required this.value,
    this.lines = const [],
    this.dark = false,
    this.smallValue = false,
    this.plainValue = false,
    this.progress,
    this.progressLabel,
  });

  /// "Registered today", "Planned today", "Away for".
  final String label;

  /// "4h 18m", "08:00 – 16:30".
  final String value;

  /// "Planned finish 16:30 · + 42m travel".
  final List<String> lines;
  final bool dark;

  /// A few words instead of a number ("Waiting for HR").
  final bool smallValue;

  /// A plain line instead of a value ("No schedule today").
  final bool plainValue;

  /// How far the day is toward its planned time, 0 to 1 (Figma `1606:2`):
  /// a slim line under the value with [progressLabel] ("of 8h 00m").
  final double? progress;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final quiet = dark ? JitanColors.sidebarText : JitanColors.inkMuted;
    final strong = dark ? JitanColors.surface : JitanColors.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: dark ? JitanColors.ink : JitanColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: JitanMobileTextStyles.label.copyWith(color: quiet)),
          SizedBox(height: smallValue || plainValue ? 6 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: plainValue
                  ? JitanMobileTextStyles.rowTitle.copyWith(fontSize: 17, color: strong)
                  : smallValue
                  ? JitanMobileTextStyles.pageTitle.copyWith(color: strong)
                  : JitanMobileTextStyles.hero.copyWith(color: strong),
            ),
          ),
          if (progress case final done?) ...[
            const SizedBox(height: 10),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: done.clamp(0, 1).toDouble()),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 4,
                        color: dark ? JitanColors.surface : JitanColors.ink,
                        backgroundColor: dark ? JitanColors.sidebarItemActive : JitanColors.inputFill,
                      ),
                    ),
                  ),
                ),
                if (progressLabel case final label?) Text(label, style: JitanMobileTextStyles.detail.copyWith(color: quiet)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          for (final line in lines) ...[const SizedBox(height: 4), Text(line, style: JitanMobileTextStyles.detail.copyWith(color: quiet))],
        ],
      ),
    );
  }
}
