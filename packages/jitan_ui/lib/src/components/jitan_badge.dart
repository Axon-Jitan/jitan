import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// A small tinted pill with a dot: a state next to a title or in a table
/// cell ("● Active", "● This group", "● Needs a choice"; Figma `1455:2`).
/// Without [dot] it is a plain count ("3").
class JitanBadge extends StatelessWidget {
  const JitanBadge({
    super.key,
    required this.label,
    this.color = JitanColors.success,
    this.background = JitanColors.successSurface,
    this.dot = true,
  });

  /// Neutral grey, e.g. a count or "No hours".
  const JitanBadge.neutral({super.key, required this.label, this.dot = false})
    : color = JitanColors.inkMuted,
      background = JitanColors.inputFill;

  /// Orange, something HR has to act on.
  const JitanBadge.warning({super.key, required this.label, this.dot = true})
    : color = JitanColors.warning,
      background = JitanColors.warningSurface;

  final String label;
  final Color color;
  final Color background;
  final bool dot;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    ),
  );
}
