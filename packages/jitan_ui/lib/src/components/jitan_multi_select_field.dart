import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_field_decoration.dart';
import 'jitan_select_field.dart';

/// A dropdown that holds several choices (Figma `HR / Add employee —
/// Companies dropdown open` 993:292, `Employee groups dropdown open`
/// 993:596): the chosen ones as chips ("Almeco ×") followed by the hint, and
/// a list below the field where a chosen row shows ✓ and the others +.
/// Choosing keeps the list open, so HR can pick several in a row.
class JitanMultiSelectField<T> extends StatefulWidget {
  const JitanMultiSelectField({
    super.key,
    this.label,
    required this.options,
    required this.values,
    required this.onChanged,
    this.hintText,
    this.errorText,
    this.locked = const {},
  });

  final String? label;
  final List<JitanSelectOption<T>> options;

  /// The chosen values, in the order they show as chips.
  final List<T> values;

  /// `null` disables the field.
  final ValueChanged<List<T>>? onChanged;
  final String? hintText;
  final String? errorText;

  /// Values that stay chosen (no ×, not removable from the list), e.g. the
  /// company HR is working in.
  final Set<T> locked;

  @override
  State<JitanMultiSelectField<T>> createState() => _JitanMultiSelectFieldState<T>();
}

class _JitanMultiSelectFieldState<T> extends State<JitanMultiSelectField<T>> {
  final _menu = MenuController();

  static const _menuGap = 6.0;
  static const _menuMaxHeight = 320.0;
  static const _menuInset = 6.0;
  static const _itemHeight = 40.0;

  bool get _enabled => widget.onChanged != null;

  void _toggle(T value) {
    if (widget.locked.contains(value)) return;
    final next = [...widget.values];
    next.contains(value) ? next.remove(value) : next.add(value);
    widget.onChanged?.call(next);
  }

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
            _Row(
              label: option.label,
              chosen: widget.values.contains(option.value),
              width: constraints.maxWidth - _menuInset * 2,
              onPressed: () => _toggle(option.value),
            ),
        ],
        builder: (context, menu, _) => _Field<T>(
          chips: [
            for (final value in widget.values)
              if (widget.options.where((o) => o.value == value).firstOrNull case final option?)
                (label: option.label, onRemove: _enabled && !widget.locked.contains(value) ? () => _toggle(value) : null),
          ],
          hintText: widget.hintText,
          open: menu.isOpen,
          enabled: _enabled,
          errorText: widget.errorText,
          onTap: _enabled ? () => menu.isOpen ? menu.close() : menu.open() : null,
        ),
      ),
    );
    final label = widget.label;
    return label == null ? field : JitanFieldLabel(label: label, child: field);
  }
}

/// A row of the open list: ✓ when chosen (on a soft grey), + otherwise.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.chosen, required this.width, required this.onPressed});

  final String label;
  final bool chosen;
  final double width;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MenuItemButton(
    closeOnActivate: false,
    onPressed: onPressed,
    leadingIcon: Icon(chosen ? Icons.check_rounded : Icons.add_rounded, size: 16, color: JitanColors.inkMuted),
    style: ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(width, _JitanMultiSelectFieldState._itemHeight)),
      maximumSize: WidgetStatePropertyAll(Size(width, _JitanMultiSelectFieldState._itemHeight)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      backgroundColor: WidgetStatePropertyAll(chosen ? JitanColors.warmWhite : null),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? Colors.transparent
            : states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
            ? JitanColors.inputFill
            : null,
      ),
    ),
    child: Text(label, overflow: TextOverflow.ellipsis, style: JitanTextStyles.inputText),
  );
}

/// The closed field: chips, then the hint, then a chevron.
class _Field<T> extends StatelessWidget {
  const _Field({
    required this.chips,
    required this.hintText,
    required this.open,
    required this.enabled,
    required this.errorText,
    required this.onTap,
  });

  final List<({String label, VoidCallback? onRemove})> chips;
  final String? hintText;
  final bool open;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
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
              side: BorderSide(color: error != null ? JitanColors.error : JitanColors.inputBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: JitanDimensions.fieldHeight),
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, top: 6, bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            for (final chip in chips) _Chip(label: chip.label, onRemove: chip.onRemove),
                            if (hintText case final hint?)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(hint, style: JitanTextStyles.inputHint),
                              ),
                          ],
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
        if (error != null) ...[const SizedBox(height: 6), Text(error, style: JitanTextStyles.fieldError)],
      ],
    );
  }
}

/// "Almeco ×": a chosen value; × removes it.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: EdgeInsets.only(left: 10, right: onRemove == null ? 10 : 4),
    decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: JitanTextStyles.tableCell)),
        if (onRemove case final remove?)
          InkWell(
            onTap: remove,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 14, color: JitanColors.inkMuted),
            ),
          ),
      ],
    ),
  );
}
