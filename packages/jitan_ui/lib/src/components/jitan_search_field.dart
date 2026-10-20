import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// Search input from the web list pages: filled (Companies, Employees), or
/// [outlined] like the select fields next to it (a toolbar of filters, e.g.
/// Schedules), at the same height.
class JitanSearchField extends StatelessWidget {
  const JitanSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.outlined = false,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final filledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
      borderSide: BorderSide.none,
    );
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      style: JitanTextStyles.inputText,
      cursorColor: JitanColors.ink,
      textInputAction: TextInputAction.search,
      decoration: outlined
          ? InputDecoration.collapsed(hintText: hintText, hintStyle: JitanTextStyles.inputHint)
          : InputDecoration(
              hintText: hintText,
              hintStyle: JitanTextStyles.inputHint,
              filled: true,
              fillColor: JitanColors.inputFill,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: filledBorder,
              enabledBorder: filledBorder,
              focusedBorder: filledBorder.copyWith(borderSide: const BorderSide(color: JitanColors.inkMuted)),
            ),
    );
    if (!outlined) return SizedBox(height: JitanDimensions.controlHeight, child: field);
    // The same box as JitanSelectField, so both are exactly the same size.
    return Container(
      height: JitanDimensions.fieldHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
        border: Border.all(color: JitanColors.inputBorder),
      ),
      child: field,
    );
  }
}
