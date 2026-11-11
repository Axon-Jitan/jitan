import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_field_decoration.dart';

/// A calm grouped card of settings (Figma `HR / Schedules V3`, `1551:2`):
/// one line per setting, thin dividers between them, as in iOS Settings.
class JitanSettingsCard extends StatelessWidget {
  const JitanSettingsCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: JitanColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: JitanColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: JitanColors.cardBorder),
          row,
        ],
      ],
    ),
  );
}

/// One line of a [JitanSettingsCard]: the name on the left (with an ⓘ when
/// [info] is given), the value or its control on the right. On a narrow
/// card a value that does not fit goes under the name.
class JitanSettingsRow extends StatelessWidget {
  const JitanSettingsRow({super.key, required this.label, required this.value, this.info});

  final String label;
  final String? info;
  final Widget value;

  /// A read-only value in the row's value style.
  static Widget text(String value) => Text(
    value,
    textAlign: TextAlign.end,
    style: JitanTextStyles.tableCell.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500),
  );

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 50),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
    // Full width, so the value sits at the right end of the line.
    child: SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          JitanLabelText(
            label: label,
            info: info,
            style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
          ),
          value,
        ],
      ),
    ),
  );
}
