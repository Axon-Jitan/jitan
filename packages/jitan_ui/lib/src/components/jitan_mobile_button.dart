import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Colour of a [JitanMobileButton].
enum JitanMobileButtonStyle {
  /// Ink: the default main action ("Get started", "Continue").
  dark,

  /// Vermilion: final or recovery actions ("Start Jitan", "Try again").
  brand,

  /// Warm grey with ink text: secondary actions ("Back").
  secondary,
}

/// Size of a [JitanMobileButton], as measured in Figma.
enum JitanMobileButtonSize {
  /// 56 px, radius 18, 15 px label.
  large(56, 18, 15),

  /// 54 px, radius 16, 14 px label (form screens).
  medium(54, 16, 14),

  /// 52 px, radius 16, 13 px label (error screens).
  compact(52, 16, 13);

  const JitanMobileButtonSize(this.height, this.radius, this.fontSize);

  final double height;
  final double radius;
  final double fontSize;
}

/// Full-width mobile button (Figma `01 — Employee App`).
///
/// [onPressed] `null` disables it. [busy] shows a spinner in place of the
/// label and ignores taps, so a request cannot be sent twice.
class JitanMobileButton extends StatelessWidget {
  const JitanMobileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = JitanMobileButtonStyle.dark,
    this.size = JitanMobileButtonSize.large,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final JitanMobileButtonStyle style;
  final JitanMobileButtonSize size;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (style) {
      JitanMobileButtonStyle.dark => (JitanColors.ink, JitanColors.warmWhite),
      JitanMobileButtonStyle.brand => (JitanColors.vermilion, JitanColors.surface),
      JitanMobileButtonStyle.secondary => (JitanColors.inputFill, JitanColors.ink),
    };
    return SizedBox(
      height: size.height,
      width: double.infinity,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: busy ? 1 : 0.4),
          disabledForegroundColor: foreground,
          textStyle: TextStyle(
            fontFamily: JitanTextStyles.fontFamily,
            package: JitanTextStyles.fontPackage,
            fontSize: size.fontSize,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.radius)),
        ),
        child: busy
            ? Semantics(
                label: label,
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
                ),
              )
            : Text(label),
      ),
    );
  }
}
