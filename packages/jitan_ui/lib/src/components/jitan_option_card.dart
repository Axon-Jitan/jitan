import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// How a [JitanOptionCard] shows its state.
enum JitanOptionIndicator {
  /// Rounded square with a check: one of several (companies, groups).
  checkbox,

  /// Circle: exactly one (language).
  radio,
}

/// A selectable row of the web assignment tabs (Figma "Option / …",
/// "Language / …"): title, detail line, indicator on the right. Selected rows
/// are tinted blue. [onTap] `null` locks the row (e.g. an existing
/// assignment that cannot be removed).
class JitanOptionCard extends StatelessWidget {
  const JitanOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
    this.indicator = JitanOptionIndicator.checkbox,
    this.height = 68,
    this.removable = false,
  });

  final String title;
  final String? detail;
  final bool selected;
  final VoidCallback? onTap;
  final JitanOptionIndicator indicator;
  final double height;

  /// A current assignment that tapping removes (Figma "Selected / removable":
  /// a green check).
  final bool removable;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    inMutuallyExclusiveGroup: indicator == JitanOptionIndicator.radio,
    enabled: onTap != null,
    child: Material(
      color: selected ? JitanColors.infoSurface : JitanColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? JitanColors.info : JitanColors.inputBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: JitanTextStyles.stateTitle.copyWith(fontSize: height < 64 ? 12 : 13)),
                      if (detail != null) ...[
                        const SizedBox(height: 8),
                        Text(detail!, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _Indicator(selected: selected, indicator: indicator, locked: onTap == null, removable: removable),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.selected, required this.indicator, required this.locked, required this.removable});

  final bool removable;

  final bool selected;
  final JitanOptionIndicator indicator;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = removable
        ? JitanColors.success
        : locked && selected
        ? JitanColors.info.withValues(alpha: 0.6)
        : JitanColors.info;
    return switch (indicator) {
      JitanOptionIndicator.checkbox => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? color : JitanColors.surface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: selected ? color : JitanColors.inputBorder),
        ),
        child: selected ? const Icon(Icons.check, size: 15, color: JitanColors.surface) : null,
      ),
      JitanOptionIndicator.radio => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : JitanColors.surface,
          border: Border.all(color: selected ? color : JitanColors.inputBorder),
        ),
      ),
    };
  }
}
