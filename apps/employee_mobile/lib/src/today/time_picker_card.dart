import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';

/// The big "08 : 04" of "When did you arrive?" (Figma 1436:2, 22:2): hours
/// and minutes typed separately, two digits each.
class TimePickerCard extends StatelessWidget {
  const TimePickerCard({super.key, required this.hours, required this.minutes});

  final TextEditingController hours;
  final TextEditingController minutes;

  @override
  Widget build(BuildContext context) {
    final style = JitanMobileTextStyles.displayLarge.copyWith(fontSize: 40, height: 1);
    Widget part(TextEditingController controller, String label) => SizedBox(
      width: 76,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
        style: style,
        cursorColor: JitanColors.ink,
        decoration: InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          semanticCounterText: label,
          hintText: '00',
          hintStyle: style.copyWith(color: JitanColors.inputBorder),
        ),
        onTap: () => controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length),
      ),
    );
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: JitanColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: JitanColors.inputBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(label: context.t(EmployeeTextKeys.entryHour), child: part(hours, context.t(EmployeeTextKeys.entryHour))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(':', style: style.copyWith(fontSize: 30, color: JitanColors.inkMuted)),
          ),
          Semantics(label: context.t(EmployeeTextKeys.entryMinute), child: part(minutes, context.t(EmployeeTextKeys.entryMinute))),
        ],
      ),
    );
  }
}
