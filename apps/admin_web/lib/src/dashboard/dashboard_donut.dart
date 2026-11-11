import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'dashboard_text.dart';

/// One part of a donut and its legend row; [onOpen] opens the page that
/// shows what it counted, `null` where no page can.
typedef DonutPart = ({String label, int value, Color color, VoidCallback? onOpen});

/// A donut with the headline in its centre and every value in the legend
/// beside it, or under it on a narrow card. Pointing at a part (on the ring
/// or in the legend) brings it forward, fades the others and shows its
/// number in the centre; a part with a page opens it on a click.
class DashboardDonut extends StatefulWidget {
  const DashboardDonut({super.key, required this.parts, required this.centre, required this.caption});

  final List<DonutPart> parts;
  final String centre;
  final String caption;

  @override
  State<DashboardDonut> createState() => _DashboardDonutState();
}

class _DashboardDonutState extends State<DashboardDonut> {
  static const _size = 160.0;
  static const _stackedBelow = 320.0;

  /// The part pointed at, as an index of [DashboardDonut.parts].
  int? _hovered;

  void _hover(int? index) {
    if (index != _hovered) setState(() => _hovered = index);
  }

  /// The part under [position] on the ring, if any.
  int? _partAt(Offset position) {
    final centre = const Offset(_size / 2, _size / 2);
    final offset = position - centre;
    final distance = offset.distance;
    if (distance > _size / 2 || distance < _size / 2 - _DonutPainter.stroke) return null;
    // Clockwise from the top, as the ring is drawn.
    var angle = math.atan2(offset.dy, offset.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final total = widget.parts.fold(0, (sum, p) => sum + p.value);
    if (total == 0) return null;
    var start = 0.0;
    for (final (i, part) in widget.parts.indexed) {
      if (part.value == 0) continue;
      final sweep = part.value / total * math.pi * 2;
      if (angle < start + sweep) return i;
      start += sweep;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hovered = _hovered == null ? null : widget.parts[_hovered!];
    final ring = MouseRegion(
      cursor: hovered?.onOpen == null ? MouseCursor.defer : SystemMouseCursors.click,
      onHover: (event) => _hover(_partAt(event.localPosition)),
      onExit: (_) => _hover(null),
      child: GestureDetector(
        onTapUp: (details) {
          final index = _partAt(details.localPosition);
          if (index != null) widget.parts[index].onOpen?.call();
        },
        child: Semantics(
          label: '${widget.centre} ${widget.caption}',
          child: SizedBox.square(
            dimension: _size,
            child: CustomPaint(
              painter: _DonutPainter(widget.parts, _hovered),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hovered == null ? widget.centre : DashboardText.number(hovered.value),
                      style: JitanTextStyles.pageTitle.copyWith(fontSize: 28),
                    ),
                    SizedBox(
                      width: _size - _DonutPainter.stroke * 2 - 12,
                      child: Text(
                        hovered?.label ?? widget.caption,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: JitanTextStyles.tableCell.copyWith(fontSize: 12, color: JitanColors.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [for (final (i, part) in widget.parts.indexed) _legendRow(i, part)],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < _stackedBelow
          ? Column(spacing: 16, children: [ring, legend])
          : Row(children: [ring, const SizedBox(width: 20), Expanded(child: legend)]),
    );
  }

  Widget _legendRow(int index, DonutPart part) {
    final hovered = _hovered == index;
    final dimmed = _hovered != null && !hovered;
    return MouseRegion(
      cursor: part.onOpen == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => _hover(index),
      onExit: (_) => _hover(null),
      child: Semantics(
        button: part.onOpen != null,
        child: GestureDetector(
          onTap: part.onOpen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: hovered && part.onOpen != null ? JitanColors.tableHover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: dimmed ? 0.45 : 1,
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
                      style: JitanTextStyles.tableCell.copyWith(color: hovered ? JitanColors.ink : JitanColors.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(DashboardText.number(part.value), style: JitanTextStyles.tableCellStrong.copyWith(fontSize: 16)),
                  SizedBox(
                    width: 22,
                    child: hovered && part.onOpen != null
                        ? const Icon(Icons.chevron_right, size: 18, color: JitanColors.inkMuted)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.parts, this.hovered);

  final List<DonutPart> parts;
  final int? hovered;

  static const stroke = 22.0;

  /// The 2 px of card between two parts, as an angle on the ring.
  static const _gap = 2 / 69;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    Paint paint(Color color, {bool faded = false}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = faded ? color.withValues(alpha: 0.3) : color;
    final shown = [
      for (final (i, part) in parts.indexed)
        if (part.value > 0) (i, part),
    ];
    final total = shown.fold(0, (sum, p) => sum + p.$2.value);
    if (shown.length < 2) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint(shown.firstOrNull?.$2.color ?? JitanColors.chartTrack));
      return;
    }
    var start = -math.pi / 2;
    for (final (i, part) in shown) {
      final sweep = part.value / total * math.pi * 2;
      final faded = hovered != null && hovered != i;
      canvas.drawArc(rect, start + _gap / 2, math.max(sweep - _gap, 0.01), false, paint(part.color, faded: faded));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.parts != parts || old.hovered != hovered;
}
