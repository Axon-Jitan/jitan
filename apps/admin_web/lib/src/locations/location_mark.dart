import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The small tile with the area's ring and pin (Figma `Location mark`).
class LocationMark extends StatelessWidget {
  const LocationMark({super.key, required this.active});

  final bool active;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final color = active ? JitanColors.vermilion : JitanColors.inkMuted;
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: JitanColors.warmWhite, borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
        child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      ),
    );
  }
}
