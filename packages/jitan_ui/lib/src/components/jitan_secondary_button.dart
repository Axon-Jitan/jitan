import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// The outlined companion of [JitanPrimaryButton] ("Cancel", "Reset account
/// access"): same height and radius, ink text on white. [onPressed] `null`
/// disables it.
class JitanSecondaryButton extends StatelessWidget {
  const JitanSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.foreground = JitanColors.ink,
    this.height = JitanDimensions.fieldHeight,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Text colour; e.g. [JitanColors.errorStrong] for an action that removes
  /// access.
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: JitanColors.surface,
        side: const BorderSide(color: JitanColors.inputBorder),
        textStyle: JitanTextStyles.buttonLabel.copyWith(color: foreground),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.inputRadius)),
      ),
      child: Text(label),
    ),
  );
}
