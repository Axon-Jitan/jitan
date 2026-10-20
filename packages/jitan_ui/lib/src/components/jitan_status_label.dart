import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// A status in a table cell: a small dot and the label on one line, 8 px
/// apart, vertically centred ("● Active" in success green).
class JitanStatusLabel extends StatelessWidget {
  const JitanStatusLabel({super.key, required this.label, required this.isPositive});

  final String label;

  /// `true` renders in the success colour, `false` in muted ink.
  final bool isPositive;

  static const _dotSize = 7.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? JitanColors.success : JitanColors.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dotSize,
          height: _dotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: _gap),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.tableCell.copyWith(color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
