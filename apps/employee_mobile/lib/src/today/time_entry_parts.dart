import 'package:flutter/material.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The pieces shared by the pages where the employee enters a time by hand:
/// Home's "Finished earlier?" (Figma `1588:2`) and Period's missing time
/// (`1595:474`).

/// "Scheduled finish 16:30 · Use it".
class ScheduledTimeRow extends StatelessWidget {
  const ScheduledTimeRow({super.key, required this.label, required this.useLabel, required this.onUse});

  /// "Scheduled finish 16:30".
  final String label;
  final String useLabel;

  /// `null` while busy.
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(width: 2),
      Expanded(child: Text(label, style: JitanMobileTextStyles.detail.copyWith(fontSize: 14))),
      TextButton(
        onPressed: onUse,
        style: TextButton.styleFrom(foregroundColor: JitanColors.ink, minimumSize: const Size(44, 44)),
        child: Text(useLabel, style: JitanMobileTextStyles.rowTitle.copyWith(fontSize: 14)),
      ),
    ],
  );
}

/// The reason HR reads, three lines high.
class EntryReasonField extends StatelessWidget {
  const EntryReasonField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 3,
      maxLength: RegisterTimeRequest.maxReasonLength,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      style: JitanMobileTextStyles.rowText.copyWith(height: 1.4),
      cursorColor: JitanColors.ink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: JitanMobileTextStyles.rowText.copyWith(color: JitanColors.inkMuted, height: 1.4),
        filled: true,
        fillColor: JitanColors.surface,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: border(JitanColors.inputBorder),
        focusedBorder: border(JitanColors.ink),
      ),
    );
  }
}
