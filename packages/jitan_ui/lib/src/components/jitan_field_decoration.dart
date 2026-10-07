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

/// A field label above its input, as in the Figma forms.
class JitanFieldLabel extends StatelessWidget {
  const JitanFieldLabel({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: JitanTextStyles.fieldLabel),
          const SizedBox(height: JitanDimensions.fieldLabelGap),
          child,
        ],
      );
}
