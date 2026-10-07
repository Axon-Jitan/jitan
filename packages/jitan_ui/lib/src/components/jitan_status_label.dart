import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Coloured status text in table cells ("Active" in success green).
class JitanStatusLabel extends StatelessWidget {
  const JitanStatusLabel({super.key, required this.label, required this.isPositive});

  final String label;

  /// `true` renders in the success colour, `false` in muted ink.
  final bool isPositive;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: JitanTextStyles.tableCell.copyWith(
          color: isPositive ? JitanColors.success : JitanColors.inkMuted,
        ),
      );
}
