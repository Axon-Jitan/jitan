import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_field_decoration.dart';

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
    return SizedBox(
      height: outlined ? JitanDimensions.fieldHeight : JitanDimensions.controlHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: JitanTextStyles.inputText,
        cursorColor: JitanColors.ink,
        textInputAction: TextInputAction.search,
        decoration: outlined
            ? jitanFieldDecoration(hintText: hintText, contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 15))
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
      ),
    );
  }
}
