import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
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
///
/// The menu opens below the field at the field's width, so it never covers
/// the field or its label; long lists scroll, and the current choice is
/// scrolled into view.
class JitanSelectField<T> extends StatefulWidget {
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

  @override
  State<JitanSelectField<T>> createState() => _JitanSelectFieldState<T>();
}

class _JitanSelectFieldState<T> extends State<JitanSelectField<T>> {
  final _menu = MenuController();

  static const _menuGap = 4.0;
  static const _menuMaxHeight = 320.0;
  static const _itemHeight = 40.0;

  bool get _enabled => widget.onChanged != null;

  void _toggle() => _menu.isOpen ? _menu.close() : _menu.open();

  @override
  Widget build(BuildContext context) {
    final field = LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        controller: _menu,
        alignmentOffset: const Offset(0, _menuGap),
        onOpen: () => setState(() {}),
        onClose: () => setState(() {}),
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(JitanColors.surface),
          surfaceTintColor: const WidgetStatePropertyAll(JitanColors.surface),
          elevation: const WidgetStatePropertyAll(6),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(JitanDimensions.inputRadius)),
          ),
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, _menuMaxHeight)),
        ),
        menuChildren: [
          for (final option in widget.options)
            MenuItemButton(
              autofocus: option.value == widget.value,
              onPressed: () => widget.onChanged?.call(option.value),
              style: ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, _itemHeight)),
                padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
                backgroundColor: WidgetStatePropertyAll(
                  option.value == widget.value ? JitanColors.inputFill : null,
                ),
              ),
              child: Text(
                option.label,
                overflow: TextOverflow.ellipsis,
                style: option.value == widget.value
                    ? JitanTextStyles.inputText.copyWith(fontWeight: FontWeight.w600)
                    : JitanTextStyles.inputText,
              ),
            ),
        ],
        builder: (context, menu, _) => _Field(
          text: _selectedLabel,
          isHint: _selectedLabel == null,
          hintText: widget.hintText,
          open: menu.isOpen,
          enabled: _enabled,
          errorText: widget.errorText,
          onTap: _enabled ? _toggle : null,
        ),
      ),
    );
    final label = widget.label;
    return label == null ? field : JitanFieldLabel(label: label, child: field);
  }

  String? get _selectedLabel => widget.options.where((o) => o.value == widget.value).firstOrNull?.label;
}

/// The closed field: current choice (or hint) and a chevron, outlined like
/// the text fields.
class _Field extends StatelessWidget {
  const _Field({
    required this.text,
    required this.isHint,
    required this.hintText,
    required this.open,
    required this.enabled,
    required this.errorText,
    required this.onTap,
  });

  final String? text;
  final bool isHint;
  final String? hintText;
  final bool open;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
    final borderColor = error != null
        ? JitanColors.error
        : open
        ? JitanColors.inkMuted
        : JitanColors.inputBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          expanded: open,
          child: Material(
            color: enabled ? JitanColors.surface : JitanColors.disabledFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
              side: BorderSide(color: borderColor),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
              onTap: onTap,
              child: SizedBox(
                height: JitanDimensions.fieldHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 11, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text ?? hintText ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: isHint
                              ? JitanTextStyles.inputHint
                              : enabled
                              ? JitanTextStyles.inputText
                              : JitanTextStyles.inputText.copyWith(color: JitanColors.disabledText),
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: enabled ? JitanColors.inkMuted : JitanColors.disabledText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error, style: JitanTextStyles.fieldError),
        ],
      ],
    );
  }
}
