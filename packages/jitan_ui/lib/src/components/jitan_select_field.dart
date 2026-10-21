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
    this.info,
  });

  final String? label;

  /// What the field means, with an example; shown from an ⓘ by the label.
  final String? info;
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

  static const _menuGap = 6.0;
  static const _menuMaxHeight = 320.0;
  static const _menuInset = 6.0;
  static const _itemHeight = 40.0;
  static const _itemRadius = 10.0;

  bool get _enabled => widget.onChanged != null;

  void _toggle() => _menu.isOpen ? _menu.close() : _menu.open();

  @override
  Widget build(BuildContext context) {
    final field = LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth - _menuInset * 2;
        return MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, _menuGap),
          onOpen: () => setState(() {}),
          onClose: () => setState(() {}),
          style: MenuStyle(
            backgroundColor: const WidgetStatePropertyAll(JitanColors.surface),
            surfaceTintColor: const WidgetStatePropertyAll(JitanColors.surface),
            shadowColor: WidgetStatePropertyAll(JitanColors.ink.withValues(alpha: 0.35)),
            elevation: const WidgetStatePropertyAll(10),
            padding: const WidgetStatePropertyAll(EdgeInsets.all(_menuInset)),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                side: BorderSide(color: JitanColors.cardBorder),
              ),
            ),
            minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
            maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, _menuMaxHeight)),
          ),
          menuChildren: [
            for (final option in widget.options)
              _MenuItem(
                label: option.label,
                selected: option.value == widget.value,
                width: itemWidth,
                height: _itemHeight,
                radius: _itemRadius,
                onPressed: () => widget.onChanged?.call(option.value),
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
        );
      },
    );
    final label = widget.label;
    return label == null ? field : JitanFieldLabel(label: label, info: widget.info, child: field);
  }

  String? get _selectedLabel => widget.options.where((o) => o.value == widget.value).firstOrNull?.label;
}

/// One choice in the open menu: a rounded row with a soft hover; the
/// current choice is bold with a check mark.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.label,
    required this.selected,
    required this.width,
    required this.height,
    required this.radius,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final double width;
  final double height;
  final double radius;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MenuItemButton(
    autofocus: selected,
    onPressed: onPressed,
    trailingIcon: selected ? const Icon(Icons.check_rounded, size: 18, color: JitanColors.vermilion) : null,
    style: ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(width, height)),
      maximumSize: WidgetStatePropertyAll(Size(width, height)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))),
      backgroundColor: WidgetStatePropertyAll(selected ? JitanColors.warmWhite : null),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? Colors.transparent
            : states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
            ? JitanColors.inputFill
            : null,
      ),
    ),
    child: Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: selected ? JitanTextStyles.inputText.copyWith(fontWeight: FontWeight.w600) : JitanTextStyles.inputText,
    ),
  );
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
    // The border stays the same while the menu is open; only an error colours it.
    final borderColor = error != null ? JitanColors.error : JitanColors.inputBorder;
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
              // A focused field keeps its look; a grey fill reads as disabled.
              focusColor: Colors.transparent,
              onTap: onTap,
              child: SizedBox(
                height: JitanDimensions.fieldHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
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
