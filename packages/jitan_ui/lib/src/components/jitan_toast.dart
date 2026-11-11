import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';

/// Says that something was done (Figma `1524:350`, "Toast"): a small dark
/// pill at the bottom with a check, the message and at most one next step.
/// The newest replaces the one showing, and every one fades, the one with
/// a next step too.
void showJitanToast(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final hasAction = actionLabel != null && onAction != null;
  final scaler = MediaQuery.textScalerOf(context);
  final screen = MediaQuery.sizeOf(context).width;

  double measure(String text, TextStyle style) =>
      (TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler)
            ..layout())
          .width;

  final contentWidth =
      JitanToast._checkSize +
      JitanToast._checkGap +
      measure(message, JitanTextStyles.toastText) +
      (hasAction ? JitanToast._actionGap + JitanToast._actionPadding * 2 + measure(actionLabel, JitanTextStyles.toastAction) : 0);
  final padding = hasAction ? JitanToast._paddingWithAction : JitanToast._padding;
  // A little room so the measured text never wraps by a rounding pixel.
  final width = math.min(contentWidth + padding.horizontal + 4, screen - 32);

  // Centred under the page that says it, not the whole window (beside the
  // sidebar on the web), 32 px above the bottom.
  final page = context.findRenderObject();
  final (pageLeft, pageWidth) = page is RenderBox && page.hasSize
      ? (page.localToGlobal(Offset.zero).dx, page.size.width)
      : (0.0, screen);
  final left = (pageLeft + (pageWidth - width) / 2).clamp(16.0, math.max(16.0, screen - width - 16)).toDouble();
  final margin = EdgeInsets.fromLTRB(left, 0, math.max(0.0, screen - left - width), JitanToast._bottom);

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: JitanToast(
          message: message,
          actionLabel: hasAction ? actionLabel : null,
          onAction: hasAction
              ? () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                }
              : null,
        ),
        behavior: SnackBarBehavior.floating,
        margin: margin,
        padding: padding,
        backgroundColor: JitanColors.ink,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        persist: false,
        duration: const Duration(seconds: 4),
      ),
    );
}

/// What a Jitan toast shows; [showJitanToast] puts it on screen.
class JitanToast extends StatelessWidget {
  const JitanToast({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const _bottom = 32.0;
  static const _checkSize = 16.0;
  static const _checkGap = 8.0;
  static const _actionGap = 16.0;
  static const _actionPadding = 14.0;
  static const _padding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
  static const _paddingWithAction = EdgeInsets.fromLTRB(18, 8, 8, 8);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.check, size: _checkSize, color: JitanColors.surface),
      const SizedBox(width: _checkGap),
      Expanded(child: Text(message, style: JitanTextStyles.toastText)),
      if (actionLabel case final label?) ...[
        const SizedBox(width: _actionGap),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            backgroundColor: JitanColors.surface.withValues(alpha: 0.12),
            foregroundColor: JitanColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: _actionPadding, vertical: 8),
            minimumSize: const Size(0, 33),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(label, style: JitanTextStyles.toastAction),
        ),
      ],
    ],
  );
}
