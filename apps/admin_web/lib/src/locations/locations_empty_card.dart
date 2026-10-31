import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// The empty Locations page (Figma `1465:177`): three calm rings around the
/// pin, one sentence and one action.
class LocationsEmptyCard extends StatelessWidget {
  const LocationsEmptyCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  static const _height = 520.0;

  @override
  Widget build(BuildContext context) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    child: SizedBox(
      height: _height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 120, height: 120, child: CustomPaint(painter: _RingsPainter())),
            const SizedBox(height: 20),
            Text(
              context.t(AdminTextKeys.locationsEmptyTitle),
              textAlign: TextAlign.center,
              style: JitanTextStyles.modalTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              context.t(AdminTextKeys.locationsEmptyText),
              textAlign: TextAlign.center,
              style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
            ),
            const SizedBox(height: 20),
            JitanPrimaryButton(
              label: context.t(AdminTextKeys.locationAdd),
              height: JitanDimensions.controlHeight,
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    Paint ring(double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..color = JitanColors.vermilion.withValues(alpha: alpha);
    canvas
      ..drawCircle(centre, 59, ring(0.12))
      ..drawCircle(centre, 39, ring(0.25))
      ..drawCircle(centre, 20, Paint()..color = JitanColors.vermilion.withValues(alpha: 0.1))
      ..drawCircle(centre, 20, ring(1))
      ..drawCircle(centre, 5, Paint()..color = JitanColors.vermilion);
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => false;
}
