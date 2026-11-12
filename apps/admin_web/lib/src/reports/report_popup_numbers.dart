import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The headline numbers on top of a report pop-up (Figma `1572:240`,
/// `1572:593`): small labels, values side by side, wrapping on a phone.
class ReportPopupNumbers extends StatelessWidget {
  const ReportPopupNumbers({super.key, required this.numbers});

  /// Label, value, and its colour (ink when `null`).
  final List<(String, String, Color?)> numbers;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 32,
    runSpacing: 12,
    children: [
      for (final (label, value, color) in numbers)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: JitanTextStyles.stateMessage.copyWith(fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: JitanTextStyles.pageTitle.copyWith(fontSize: 20, color: color ?? JitanColors.ink)),
          ],
        ),
    ],
  );
}
