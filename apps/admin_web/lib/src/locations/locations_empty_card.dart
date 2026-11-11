import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// No locations yet (Figma `1543:318`): on the page itself, no card; one
/// line and the one thing to do, like Companies.
class LocationsEmptyCard extends StatelessWidget {
  const LocationsEmptyCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 140),
    child: Column(
      spacing: 8,
      children: [
        Text(
          context.t(AdminTextKeys.locationsEmptyTitle),
          textAlign: TextAlign.center,
          style: JitanTextStyles.modalTitle.copyWith(fontSize: 22),
        ),
        Text(
          context.t(AdminTextKeys.locationsEmptyText),
          textAlign: TextAlign.center,
          style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
        ),
        const SizedBox(height: 10),
        JitanPrimaryButton(
          label: context.t(AdminTextKeys.locationAdd),
          icon: Icons.add,
          height: JitanDimensions.controlHeight,
          onPressed: onAdd,
        ),
      ],
    ),
  );
}
