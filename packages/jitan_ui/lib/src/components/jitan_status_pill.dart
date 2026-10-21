import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Small rounded status badge: green, e.g. "READY TO SCAN" (Figma
/// `153:464`), or [neutral] grey, e.g. "Not activated" (Figma `1233:2`).
class JitanStatusPill extends StatelessWidget {
  const JitanStatusPill({super.key, required this.label, this.neutral = false});

  final String label;
  final bool neutral;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: neutral ? JitanColors.inputFill : JitanColors.successSurface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: neutral ? const EdgeInsets.symmetric(horizontal: 22, vertical: 8) : const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          child: Text(
            label,
            style: neutral
                ? JitanTextStyles.stateMessage.copyWith(fontSize: 13)
                : JitanTextStyles.fieldLabel.copyWith(fontSize: 9, color: JitanColors.success),
          ),
        ),
      );
}
