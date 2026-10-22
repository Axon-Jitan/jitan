import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_field_decoration.dart';

/// A labelled text input from the Figma forms ("First name", …).
class JitanTextField extends StatelessWidget {
  const JitanTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.errorText,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.inputFormatters = const [],
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;

  /// Shown under the field, with a red outline, when not null.
  final String? errorText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Stops input at this many characters (no counter is shown). The server
  /// still validates: this is only for quick feedback.
  final int? maxLength;

  /// Arrange or limit what is typed (e.g. a phone number's grouping).
  final List<TextInputFormatter> inputFormatters;

  /// More than 1 makes a text area (e.g. a reason); Enter then adds a line.
  final int maxLines;

  @override
  Widget build(BuildContext context) => JitanFieldLabel(
        label: label,
        child: TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType ?? (maxLines > 1 ? TextInputType.multiline : null),
          textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
          maxLines: maxLines,
          minLines: maxLines > 1 ? maxLines : null,
          onSubmitted: onSubmitted,
          inputFormatters: [...inputFormatters, if (maxLength case final max?) LengthLimitingTextInputFormatter(max)],
          style: JitanTextStyles.inputText,
          cursorColor: JitanColors.ink,
          decoration: jitanFieldDecoration(hintText: hintText, errorText: errorText),
        ),
      );
}
