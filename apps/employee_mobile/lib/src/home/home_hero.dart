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
          for (final line in lines) ...[
            const SizedBox(height: 4),
            Text(line, style: JitanMobileTextStyles.detail.copyWith(color: quiet)),
          ],
        ],
      ),
    );
  }
}
