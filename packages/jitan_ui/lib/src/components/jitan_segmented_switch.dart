import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Two or three choices filling the width, the chosen one raised in white
/// (Figma `1562:101` "Client site · Our workshop", `1566:272` "Add the
/// finish · Not a work day"). `null` [onChanged] keeps it fixed.
class JitanSegmentedSwitch<T> extends StatelessWidget {
  const JitanSegmentedSwitch({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(12)),
    child: Row(
      spacing: 3,
      children: [
        for (final (option, label) in options)
          Expanded(
            child: Semantics(
              button: true,
              selected: option == value,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onChanged == null ? null : () => onChanged!(option),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: option == value ? JitanColors.surface : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: option == value
                        ? JitanTextStyles.tableCellStrong
                        : JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
