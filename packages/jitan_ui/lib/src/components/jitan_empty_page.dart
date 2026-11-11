import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';
import 'jitan_primary_button.dart';

/// A page with nothing on it yet (Companies `1524:453`, Locations `1543:318`,
/// Terminals `1545:955`): on the page itself, no card; one line and the one
/// thing to do.
class JitanEmptyPage extends StatelessWidget {
  const JitanEmptyPage({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 140),
    child: Column(
      spacing: 8,
      children: [
        Text(title, textAlign: TextAlign.center, style: JitanTextStyles.modalTitle.copyWith(fontSize: 22)),
        Text(message, textAlign: TextAlign.center, style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted)),
        const SizedBox(height: 10),
        JitanPrimaryButton(label: actionLabel, icon: Icons.add, height: JitanDimensions.controlHeight, onPressed: onAction),
      ],
    ),
  );
}
