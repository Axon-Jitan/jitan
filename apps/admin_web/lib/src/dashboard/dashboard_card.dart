import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// A Dashboard card: title, one line under it, and its content.
class DashboardCard extends StatelessWidget {
  const DashboardCard({super.key, required this.title, this.note, this.trailing, required this.child});

  final String title;
  final String? note;

  /// Beside the title (a chart's legend); under it on a narrow card.
  final Widget? trailing;
  final Widget child;

  static const _narrow = 460.0;

  static final titleStyle = JitanTextStyles.stateTitle.copyWith(fontSize: 17);

  @override
  Widget build(BuildContext context) => JitanSurfaceCard(
    radius: JitanDimensions.tableCardRadius,
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: titleStyle)),
            if (note case final note?) ...[
              const SizedBox(height: 4),
              Text(note, style: JitanTextStyles.tableCell.copyWith(fontSize: 13, color: JitanColors.inkMuted)),
            ],
          ],
        );
        final trailing = this.trailing;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (trailing != null && constraints.maxWidth >= _narrow)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: heading), const SizedBox(width: 16), trailing],
              )
            else ...[
              heading,
              if (trailing != null) ...[const SizedBox(height: 10), Align(alignment: Alignment.centerLeft, child: trailing)],
            ],
            const SizedBox(height: 16),
            child,
          ],
        );
      },
    ),
  );
}
