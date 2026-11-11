import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// Shared outlined look of form inputs (text and select fields).
InputDecoration jitanFieldDecoration({
  String? hintText,
  String? errorText,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(horizontal: 11, vertical: 15.5),
}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hintText,
    hintStyle: JitanTextStyles.inputHint,
    errorText: errorText,
    errorStyle: JitanTextStyles.fieldError,
    // A message wraps instead of being cut off.
    errorMaxLines: 3,
    isDense: true,
    filled: true,
    fillColor: JitanColors.surface,
    contentPadding: contentPadding,
    border: border(JitanColors.inputBorder),
    enabledBorder: border(JitanColors.inputBorder),
    focusedBorder: border(JitanColors.inkMuted),
    errorBorder: border(JitanColors.error),
    focusedErrorBorder: border(JitanColors.error),
  );
}

/// A field label above its input, as in the Figma forms, with an optional
/// ⓘ that explains the field ([info]).
class JitanFieldLabel extends StatelessWidget {
  const JitanFieldLabel({super.key, required this.label, required this.child, this.info, this.note});

  final String label;
  final Widget child;

  /// What the field means, with an example; shown from the ⓘ.
  final String? info;

  /// A quiet word after the label, e.g. "Optional" (Figma `1536:2`).
  final String? note;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          JitanLabelText(label: label, info: info, note: note),
          const SizedBox(height: JitanDimensions.fieldLabelGap),
          child,
        ],
      );
}

/// A label with an optional ⓘ after it (also for column headings).
class JitanLabelText extends StatelessWidget {
  const JitanLabelText({super.key, required this.label, this.info, this.style, this.note});

  final String label;
  final String? info;
  final TextStyle? style;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    final text = note == null
        ? Text(label, style: style ?? JitanTextStyles.fieldLabel)
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                TextSpan(text: '  $note', style: const TextStyle(color: JitanColors.disabledText, fontWeight: FontWeight.w400)),
              ],
            ),
            style: style ?? JitanTextStyles.fieldLabel,
          );
    final info = this.info;
    if (info == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        const SizedBox(width: 6),
        JitanInfoIcon(message: info),
      ],
    );
  }
}

/// A small ⓘ that shows [message] on hover, tap or keyboard focus.
class JitanInfoIcon extends StatelessWidget {
  const JitanInfoIcon({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: message,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 8),
        waitDuration: const Duration(milliseconds: 200),
        preferBelow: false,
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: JitanColors.ink, borderRadius: BorderRadius.circular(10)),
        textStyle: JitanTextStyles.inputText.copyWith(color: JitanColors.surface, fontSize: 13, height: 1.4),
        child: const Icon(Icons.info_outline, size: 15, color: JitanColors.inkMuted),
      );
}
