import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// The Vermilion action button ("Add company", "Create employee", …).
///
/// [onPressed] `null` disables it. [busy] shows a spinner in place of the
/// label and ignores taps, so a request cannot be sent twice.
class JitanPrimaryButton extends StatelessWidget {
  const JitanPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.height = JitanDimensions.fieldHeight,
    this.color = JitanColors.vermilion,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final double height;

  /// Fill colour: Vermilion, or [JitanColors.errorStrong] to confirm an
  /// action that removes access (Figma "Button / Confirm reset").
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: FilledButton(
          onPressed: busy ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: JitanColors.surface,
            // Saving keeps the colour; unavailable is clearly grey, not a pale
            // version of the colour that looks like an error.
            disabledBackgroundColor: busy ? color : JitanColors.disabledFill,
            disabledForegroundColor: busy ? JitanColors.surface : JitanColors.disabledText,
            textStyle: JitanTextStyles.buttonLabel,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.inputRadius)),
          ),
          child: busy
              ? Semantics(
                  label: label,
                  child: const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: JitanColors.surface),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 6)],
                    Text(label),
                  ],
                ),
        ),
      );
}
