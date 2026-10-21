import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// The white web button with a thin border (Figma "Button / Import",
/// "Button / Choose file"): same height and radius as [JitanPrimaryButton],
/// for the second action beside it. [onPressed] `null` disables it.
class JitanOutlineButton extends StatelessWidget {
  const JitanOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = JitanDimensions.fieldHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: JitanColors.surface,
        foregroundColor: JitanColors.ink,
        disabledForegroundColor: JitanColors.disabledText,
        side: const BorderSide(color: JitanColors.inputBorder),
        textStyle: JitanTextStyles.buttonLabel,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.inputRadius)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
