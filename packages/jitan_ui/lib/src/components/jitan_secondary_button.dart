import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// The warm-grey web button (Figma "Button / Cancel", "Button / Reset account
/// access"): same height and radius as [JitanPrimaryButton]. [onPressed]
/// `null` disables it (Figma "— Disabled": grey fill, grey label).
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

  /// Label colour; [JitanColors.errorStrong] for an action that removes
  /// access ("Reset account access").
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: JitanColors.inputFill,
        foregroundColor: foreground,
        disabledBackgroundColor: JitanColors.disabledFill,
        disabledForegroundColor: JitanColors.disabledText,
        textStyle: JitanTextStyles.buttonLabel,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.inputRadius)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
