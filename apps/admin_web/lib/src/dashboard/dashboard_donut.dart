import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'dashboard_text.dart';

/// One part of a donut and its legend row.
typedef DonutPart = ({String label, int value, Color color});

/// A donut with the headline in its centre and every value in the legend
/// beside it, or under it on a narrow card.
class DashboardDonut extends StatelessWidget {
  const DashboardDonut({super.key, required this.parts, required this.centre, required this.caption});

  final List<DonutPart> parts;
  final String centre;
  final String caption;

  static const _size = 160.0;
  static const _stackedBelow = 320.0;

  @override
  Widget build(BuildContext context) {
    final donut = Semantics(
      label: '$centre $caption',
      child: SizedBox.square(
        dimension: _size,
        child: CustomPaint(
          painter: _DonutPainter(parts),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(centre, style: JitanTextStyles.pageTitle.copyWith(fontSize: 28)),
                Text(caption, style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted)),
              ],
            ),
          ),
        ),
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [for (final part in parts) _legendRow(part)],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < _stackedBelow
          ? Column(spacing: 16, children: [donut, legend])
          : Row(
              children: [donut, const SizedBox(width: 28), Expanded(child: legend)],
            ),
    );
  }

  Widget _legendRow(DonutPart part) => SizedBox(
    height: 30,
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: part.color, borderRadius: BorderRadius.circular(3)),
          child: const SizedBox.square(dimension: 10),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            part.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: JitanTextStyles.tableCell.copyWith(color: JitanColors.inkMuted),
          ),
        ),
        const SizedBox(width: 10),
        Text(DashboardText.number(part.value), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 16)),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.parts);

  final List<DonutPart> parts;

  static const _stroke = 22.0;

  /// The 2 px of card between two parts, as an angle on the ring.
  static const _gap = 2 / 69;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    Paint paint(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;
    final shown = parts.where((p) => p.value > 0).toList();
    final total = shown.fold(0, (sum, p) => sum + p.value);
    if (shown.length < 2) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint(shown.firstOrNull?.color ?? JitanColors.chartTrack));
      return;
    }
    var start = -math.pi / 2;
    for (final part in shown) {
      final sweep = part.value / total * math.pi * 2;
      canvas.drawArc(rect, start + _gap / 2, math.max(sweep - _gap, 0.01), false, paint(part.color));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.parts != parts;
}
