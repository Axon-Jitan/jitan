import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import 'jitan_data_table.dart';
import 'jitan_surface_card.dart';

/// [JitanDataTable] for a scrolling list page ([JitanListPage]): a sliver
/// whose heading row stays in view while its rows pass (pinned, with a soft
/// shadow), rows built only as they come into view, and an optional
/// [footer] (e.g. "Showing 4 of 124") closing the card. Narrower than
/// [minWidth] it is one card that scrolls sideways instead.
class JitanSliverTable extends StatelessWidget {
  const JitanSliverTable({
    super.key,
    required this.columns,
    required this.rowCount,
    required this.cells,
    this.footer,
    this.minWidth = 760,
    this.rowColor,
  });

  final List<JitanTableColumn> columns;
  final int rowCount;

  /// The cells of row [index], in column order.
  final List<Widget> Function(int index) cells;
  final Widget? footer;
  final double minWidth;

  /// As [JitanDataTable.rowColor].
  final Color? Function(int index)? rowColor;

  static const _radius = Radius.circular(JitanDimensions.tableCardRadius);

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final footer = this.footer;
      if (constraints.crossAxisExtent < minWidth) {
        return SliverToBoxAdapter(
          child: JitanSurfaceCard(
            radius: JitanDimensions.tableCardRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                JitanDataTable(
                  columns: columns,
                  minWidth: minWidth,
                  rows: [for (var i = 0; i < rowCount; i++) cells(i)],
                  rowColor: rowColor,
                ),
                ?footer,
              ],
            ),
          ),
        );
      }
      return SliverMainAxisGroup(
        slivers: [
          SliverPersistentHeader(pinned: true, delegate: _PinnedHeading(columns)),
          SliverList.builder(
            itemCount: rowCount,
            itemBuilder: (context, i) {
              final row = ColoredBox(
                color: rowColor?.call(i) ?? (i.isOdd ? JitanColors.tableStripe : JitanColors.surface),
                child: JitanTableRow(columns: columns, cells: cells(i)),
              );
              // Without a footer the last row closes the card.
              return footer == null && i == rowCount - 1
                  ? ClipRRect(
                      borderRadius: const BorderRadius.only(bottomLeft: _radius, bottomRight: _radius),
                      child: row,
                    )
                  : row;
            },
          ),
          if (footer != null)
            SliverToBoxAdapter(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: JitanColors.surface,
                  borderRadius: BorderRadius.only(bottomLeft: _radius, bottomRight: _radius),
                ),
                child: footer,
              ),
            ),
        ],
      );
    },
  );
}

/// The heading row as a pinned sliver header, drawn as the top of the card.
class _PinnedHeading extends SliverPersistentHeaderDelegate {
  const _PinnedHeading(this.columns);

  final List<JitanTableColumn> columns;

  static const _top = BorderRadius.only(topLeft: JitanSliverTable._radius, topRight: JitanSliverTable._radius);

  @override
  double get minExtent => JitanDimensions.tableHeaderHeight;

  @override
  double get maxExtent => JitanDimensions.tableHeaderHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => DecoratedBox(
    // A soft shadow while rows pass beneath it.
    decoration: BoxDecoration(
      borderRadius: _top,
      boxShadow: [
        if (overlapsContent || shrinkOffset > 0)
          BoxShadow(color: JitanColors.ink.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3)),
      ],
    ),
    child: ClipRRect(borderRadius: _top, child: JitanTableHeaderRow(columns: columns)),
  );

  @override
  bool shouldRebuild(_PinnedHeading old) =>
      old.columns.map((c) => c.label).join('|') != columns.map((c) => c.label).join('|');
}

/// A loading, empty or error state in the table card, as a sliver.
class JitanTableStateSliver extends StatelessWidget {
  const JitanTableStateSliver({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: JitanSurfaceCard(
      radius: JitanDimensions.tableCardRadius,
      child: SizedBox(height: JitanDimensions.tableStateHeight, child: child),
    ),
  );
}
