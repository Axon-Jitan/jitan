import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// Filled search input from the web list pages.
class JitanSearchField extends StatelessWidget {
  const JitanSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
      borderSide: BorderSide.none,
    );
    return SizedBox(
      height: JitanDimensions.controlHeight,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: JitanTextStyles.inputText,
        cursorColor: JitanColors.ink,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: JitanTextStyles.inputHint,
          filled: true,
          fillColor: JitanColors.inputFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: JitanColors.inkMuted),
          ),
        ),
      ),
    );
  }
}
