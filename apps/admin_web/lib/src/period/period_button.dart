import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'chosen_period.dart';
import 'period_picker.dart';
import 'period_text.dart';

/// The chosen period, closed: it looks like the other pickers (a
/// [JitanSelectField]: same height, border, text and chevron), and opens the
/// period picker under itself.
class PeriodButton extends StatefulWidget {
  const PeriodButton({
    super.key,
    required this.period,
    required this.today,
    required this.onChanged,
    this.expanded = false,
  });

  final ChosenPeriod period;
  final DateTime today;
  final ValueChanged<ChosenPeriod> onChanged;

  /// Full width, on a phone.
  final bool expanded;

  @override
  State<PeriodButton> createState() => _PeriodButtonState();
}

class _PeriodButtonState extends State<PeriodButton> {
  bool _open = false;

  Future<void> _show() async {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _open = true);
    final chosen = await showPeriodPicker(context, anchor: anchor, period: widget.period, today: widget.today);
    if (mounted) setState(() => _open = false);
    if (chosen != null) widget.onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(JitanDimensions.inputRadius);
    final period = widget.period;
    return Semantics(
      button: true,
      expanded: _open,
      child: Material(
        color: JitanColors.surface,
        shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: JitanColors.inputBorder)),
        child: InkWell(
          borderRadius: radius,
          focusColor: Colors.transparent,
          onTap: _show,
          child: SizedBox(
            height: JitanDimensions.fieldHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Row(
                mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // Both give way on a narrow line (a phone, beside Export).
                  Flexible(
                    child: Text(
                      context.t(period.preset.labelKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JitanTextStyles.inputText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    fit: widget.expanded ? FlexFit.tight : FlexFit.loose,
                    child: Text(
                      PeriodText.range(context, period.from, period.to),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JitanTextStyles.inputText.copyWith(color: JitanColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(Icons.keyboard_arrow_down, size: 18, color: JitanColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
