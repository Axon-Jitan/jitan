import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Add employee's progress (Figma `1536:2`): three slim segments, the done
/// and current ones dark, and "Step 1 of 3 · Details" under them.
class AddEmployeeProgress extends StatelessWidget {
  const AddEmployeeProgress({super.key, required this.step, required this.label});

  /// 1, 2 or 3.
  final int step;

  /// The step's name ("Details", "Work", "Set up").
  final String label;

  static const total = 3;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        spacing: 6,
        children: [
          for (var i = 1; i <= total; i++)
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? JitanColors.ink : JitanColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        context.t(AdminTextKeys.employeeAddProgress, args: {'n': step, 'total': total, 'step': label}),
        style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted, fontWeight: FontWeight.w500),
      ),
    ],
  );
}
