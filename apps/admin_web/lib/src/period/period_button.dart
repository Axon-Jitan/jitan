import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'dashboard_period.dart';
import 'dashboard_period_picker.dart';
import 'dashboard_text.dart';

/// The period at the top right; opens the picker under itself.
class DashboardPeriodButton extends StatelessWidget {
  const DashboardPeriodButton({
    super.key,
    required this.period,
    required this.today,
    required this.onChanged,
    this.expanded = false,
  });

  final DashboardPeriod period;
  final DateTime today;
  final ValueChanged<DashboardPeriod> onChanged;

  /// Full width, on a phone.
  final bool expanded;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final chosen = await showDashboardPeriodPicker(context, anchor: anchor, period: period, today: today);
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(JitanDimensions.inputRadius);
    return Material(
      color: JitanColors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: JitanColors.inputBorder)),
      child: InkWell(
        borderRadius: radius,
        hoverColor: JitanColors.tableHover,
        onTap: () => _open(context),
        child: SizedBox(
          height: 42,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: JitanColors.ink),
                const SizedBox(width: 10),
                Text(context.t(period.preset.labelKey), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 13)),
                const SizedBox(width: 10),
                Flexible(
                  fit: expanded ? FlexFit.tight : FlexFit.loose,
                  child: Text(
                    DashboardText.range(context, period.from, period.to),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.keyboard_arrow_down, size: 18, color: JitanColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
