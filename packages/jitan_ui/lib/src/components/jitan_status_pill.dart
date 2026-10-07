import 'package:flutter/widgets.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Small rounded status badge, e.g. "READY TO SCAN" (Figma `153:464`).
class JitanStatusPill extends StatelessWidget {
  const JitanStatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: JitanColors.successSurface, borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          child: Text(
            label,
            style: JitanTextStyles.fieldLabel.copyWith(fontSize: 9, color: JitanColors.success),
          ),
        ),
      );
}
