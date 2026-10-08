import 'package:flutter/material.dart';

import '../theme/jitan_text_styles.dart';
import 'jitan_field_decoration.dart';

/// One choice of a [JitanSelectField].
class JitanSelectOption<T> {
  const JitanSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// A dropdown with the same look as [JitanTextField] (e.g. "Employee
/// type"), labelled unless [label] is `null`.
class JitanSelectField<T> extends StatelessWidget {
  const JitanSelectField({
    super.key,
    this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.errorText,
  });

  final String? label;
  final List<JitanSelectOption<T>> options;
  final T? value;

  /// `null` disables the field.
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? errorText;

  static const _iconSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      style: JitanTextStyles.inputText,
      hint: hintText == null ? null : Text(hintText!, style: JitanTextStyles.inputHint),
      iconSize: _iconSize,
      // Icon height + vertical padding = the text fields' 44 px.
      decoration: jitanFieldDecoration(
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem<T>(value: option.value, child: Text(option.label, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
    final label = this.label;
    return label == null ? field : JitanFieldLabel(label: label, child: field);
  }
}
