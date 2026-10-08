import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Segmented tabs of the web modals (Figma "Assignment tabs"): 154 × 40 px
/// pills, ink when selected, warm grey otherwise.
class JitanTabBar extends StatelessWidget {
  const JitanTabBar({super.key, required this.labels, required this.selected, required this.onSelected});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (i, label) in labels.indexed) ...[
        if (i > 0) const SizedBox(width: 8),
        SizedBox(
          width: 154,
          child: Semantics(
            selected: i == selected,
            button: true,
            child: Material(
              color: i == selected ? JitanColors.ink : JitanColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(i),
                child: SizedBox(
                  height: 40,
                  child: Center(
                    child: Text(
                      label,
                      style: JitanTextStyles.tableCell.copyWith(
                        fontSize: 12,
                        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
                        color: i == selected ? JitanColors.surface : JitanColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
