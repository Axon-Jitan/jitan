import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// A few choices side by side on a light track, the chosen one on a white
/// pill (Figma `1515:2` "Employees | Projects", `1524:2` "All · Active ·
/// Inactive"): one click, and the current choice always shows.
class JitanPillSwitch<T> extends StatelessWidget {
  const JitanPillSwitch({super.key, required this.options, required this.value, required this.onChanged});

  /// Each choice and its label, in order.
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Narrower than its choices (a phone), the track scrolls sideways.
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DecoratedBox(
      decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(11)),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            for (final (option, label) in options)
              _Pill(label: label, selected: option == value, onTap: () => onChanged(option)),
          ],
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? JitanColors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selected ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: JitanColors.ink.withValues(alpha: 0.08), blurRadius: 3, offset: const Offset(0, 1))],
                )
              : null,
          child: Text(
            label,
            style: JitanTextStyles.tableCell.copyWith(
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? JitanColors.ink : JitanColors.inkMuted,
            ),
          ),
        ),
      ),
    ),
  );
}
