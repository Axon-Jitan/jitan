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
              JitanMenuItem(
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
/// One choice in a [jitanMenuStyle] menu; [selected] shows a check.
class JitanMenuItem extends StatelessWidget {
  const JitanMenuItem({
    super.key,
    required this.label,
    required this.width,
    required this.onPressed,
    this.selected = false,
    this.height = 40,
    this.radius = 10,
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

/// A choice shown as plain text with a small chevron, for the value side
/// of a settings row (Figma `1551:2`, "Blue collar ⌄"). The menu opens
/// under it, right-aligned, [menuWidth] wide.
class JitanInlineSelect<T> extends StatefulWidget {
  const JitanInlineSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.menuWidth = 240,
  });

  final List<JitanSelectOption<T>> options;
  final T? value;

  /// `null` shows the value without a chevron, unchangeable.
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final double menuWidth;

  @override
  State<JitanInlineSelect<T>> createState() => _JitanInlineSelectState<T>();
}

class _JitanInlineSelectState<T> extends State<JitanInlineSelect<T>> {
  final _menu = MenuController();
  final _anchor = GlobalKey();

  /// Moves the menu left so its right edge lines up with the value's.
  Offset _offset = const Offset(0, 6);

  void _toggle() {
    if (_menu.isOpen) return _menu.close();
    final width = (_anchor.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? widget.menuWidth;
    setState(() => _offset = Offset(width - widget.menuWidth, 6));
    _menu.open();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options.where((o) => o.value == widget.value).firstOrNull?.label;
    final enabled = widget.onChanged != null;
    final text = Text(
      selected ?? widget.hintText ?? '',
      overflow: TextOverflow.ellipsis,
      style: JitanTextStyles.tableCell.copyWith(
        color: selected == null ? JitanColors.inkMuted : JitanColors.ink,
        fontWeight: FontWeight.w500,
      ),
    );
    if (!enabled) return text;
    const inset = _JitanSelectFieldState._menuInset;
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: _offset,
      style: jitanMenuStyle(widget.menuWidth),
      menuChildren: [
        for (final option in widget.options)
          JitanMenuItem(
            label: option.label,
            selected: option.value == widget.value,
            width: widget.menuWidth - inset * 2,
            height: _JitanSelectFieldState._itemHeight,
            radius: _JitanSelectFieldState._itemRadius,
            onPressed: () => widget.onChanged?.call(option.value),
          ),
      ],
      builder: (context, menu, _) => Semantics(
        key: _anchor,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Flexible(child: text),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: JitanColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The white menu of [JitanInlineSelect], [JitanFilterSelect] and other
/// menus (Export), [width] wide.
MenuStyle jitanMenuStyle(double width) => MenuStyle(
  backgroundColor: const WidgetStatePropertyAll(JitanColors.surface),
  surfaceTintColor: const WidgetStatePropertyAll(JitanColors.surface),
  shadowColor: WidgetStatePropertyAll(JitanColors.ink.withValues(alpha: 0.35)),
  elevation: const WidgetStatePropertyAll(10),
  padding: const WidgetStatePropertyAll(EdgeInsets.all(_JitanSelectFieldState._menuInset)),
  shape: const WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      side: BorderSide(color: JitanColors.cardBorder),
    ),
  ),
  minimumSize: WidgetStatePropertyAll(Size(width, 0)),
  maximumSize: WidgetStatePropertyAll(Size(width, _JitanSelectFieldState._menuMaxHeight)),
);

/// A filter as a compact outlined button: an optional muted [label]
/// ("Company"), the chosen value, an optional muted [detail] ("9–15 Nov")
/// and a chevron (Figma `1565:2`). The menu opens under it, from its left
/// edge, or ending at its right edge with [alignEnd].
class JitanFilterSelect<T> extends StatefulWidget {
  const JitanFilterSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.detail,
    this.menuWidth = 240,
    this.alignEnd = false,
    this.expanded = false,
  });

  final List<JitanSelectOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? label;
  final String? detail;
  final double menuWidth;
  final bool alignEnd;

  /// Full width (a phone): the value takes the room, the chevron sits right.
  final bool expanded;

  @override
  State<JitanFilterSelect<T>> createState() => _JitanFilterSelectState<T>();
}

class _JitanFilterSelectState<T> extends State<JitanFilterSelect<T>> {
  final _menu = MenuController();
  final _anchor = GlobalKey();
  Offset _offset = const Offset(0, 6);

  void _toggle() {
    if (_menu.isOpen) return _menu.close();
    final width = (_anchor.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? widget.menuWidth;
    setState(() => _offset = Offset(widget.alignEnd ? width - widget.menuWidth : 0, 6));
    _menu.open();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options.where((o) => o.value == widget.value).firstOrNull?.label ?? '';
    final radius = BorderRadius.circular(JitanDimensions.inputRadius);
    final muted = JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted);
    final value = Text(
      selected,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
    );
    const inset = _JitanSelectFieldState._menuInset;
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: _offset,
      style: jitanMenuStyle(widget.menuWidth),
      menuChildren: [
        for (final option in widget.options)
          JitanMenuItem(
            label: option.label,
            selected: option.value == widget.value,
            width: widget.menuWidth - inset * 2,
            height: _JitanSelectFieldState._itemHeight,
            radius: _JitanSelectFieldState._itemRadius,
            onPressed: () => widget.onChanged(option.value),
          ),
      ],
      builder: (context, menu, _) => Semantics(
        key: _anchor,
        button: true,
        expanded: menu.isOpen,
        child: Material(
          color: JitanColors.surface,
          shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: JitanColors.inputBorder)),
          child: InkWell(
            borderRadius: radius,
            onTap: _toggle,
            child: SizedBox(
              height: JitanDimensions.controlHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Row(
                  mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
                  spacing: 8,
                  children: [
                    if (widget.label case final label?) Text(label, maxLines: 1, style: muted),
                    if (widget.expanded) Expanded(child: value) else Flexible(child: value),
                    if (widget.detail case final detail?) Text(detail, maxLines: 1, style: muted),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: JitanColors.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
