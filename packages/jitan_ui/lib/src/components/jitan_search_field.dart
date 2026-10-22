import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// Search input from the web list pages: filled (Companies, Employees), or
/// [outlined] like the select fields next to it (a toolbar of filters, e.g.
/// Schedules), at the same height.
///
/// While it holds text, a small × clears it (and so does Esc), reporting ''
/// to [onChanged].
class JitanSearchField extends StatefulWidget {
  const JitanSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.outlined = false,
    this.clearTooltip = 'Clear',
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool outlined;

  /// The × button's tooltip and accessible name (translated by the caller).
  final String clearTooltip;

  @override
  State<JitanSearchField> createState() => _JitanSearchFieldState();
}

class _JitanSearchFieldState extends State<JitanSearchField> {
  TextEditingController? _own;
  final _focus = FocusNode();

  TextEditingController get _controller => widget.controller ?? (_own ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focus.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(JitanSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_rebuild);
      _controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _own?.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final clear = hasText
        ? IconButton(
            tooltip: widget.clearTooltip,
            onPressed: _clear,
            icon: const Icon(Icons.close_rounded, size: 16, color: JitanColors.inkMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          )
        : null;
    final filledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
      borderSide: BorderSide.none,
    );
    final field = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: widget.onChanged,
        style: JitanTextStyles.inputText,
        cursorColor: JitanColors.ink,
        textInputAction: TextInputAction.search,
        decoration: widget.outlined
            ? InputDecoration.collapsed(hintText: widget.hintText, hintStyle: JitanTextStyles.inputHint)
            : InputDecoration(
                hintText: widget.hintText,
                hintStyle: JitanTextStyles.inputHint,
                filled: true,
                fillColor: JitanColors.inputFill,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                border: filledBorder,
                enabledBorder: filledBorder,
                focusedBorder: filledBorder.copyWith(borderSide: const BorderSide(color: JitanColors.inkMuted)),
                suffixIcon: clear,
              ),
      ),
    );
    if (!widget.outlined) return SizedBox(height: JitanDimensions.controlHeight, child: field);
    // The same box as JitanSelectField, so both are exactly the same size;
    // the border darkens while typing.
    return Container(
      height: JitanDimensions.fieldHeight,
      padding: EdgeInsets.only(left: 14, right: clear == null ? 14 : 6),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(JitanDimensions.inputRadius),
        border: Border.all(color: _focus.hasFocus ? JitanColors.inkMuted : JitanColors.inputBorder),
      ),
      child: Row(children: [Expanded(child: field), ?clear]),
    );
  }
}
