import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// How a [JitanTableColumn]'s heading and cells are aligned.
enum JitanColumnAlign { start, center, end }

/// A column of [JitanDataTable]. [flex] sets its share of the width.
class JitanTableColumn {
  const JitanTableColumn({required this.label, required this.flex, this.align = JitanColumnAlign.start});

  final String label;
  final int flex;

  /// Names and text: start. Numbers: as the module's design says. Actions:
  /// end (the rightmost column).
  final JitanColumnAlign align;
}

/// The one table of the HR and Admin web pages (table design specification,
/// 2026-10-20): a full-width warm-gray header, compact rows with subtle
/// full-width alternating backgrounds, no grid lines, text vertically
/// centred and cut with "…" instead of overlapping the next column.
///
/// The table is as tall as its rows. With [maxHeight], a long table keeps
/// its header and scrolls its rows inside that height. Below [minWidth] it
/// scrolls horizontally instead of squashing its columns.
///
/// With [onRowTap], rows are clickable (hover highlight, keyboard focusable,
/// announced as buttons).
class JitanDataTable extends StatelessWidget {
  const JitanDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 760,
    this.maxHeight,
    this.onRowTap,
    this.rowColor,
  });

  final List<JitanTableColumn> columns;

  /// One list of cell widgets per row, in column order.
  final List<List<Widget>> rows;
  final double minWidth;
  final double? maxHeight;

  /// Called with the row index.
  final ValueChanged<int>? onRowTap;

  /// A background for the row at an index that needs attention (e.g.
  /// [JitanColors.errorSurface] for a row with a problem); `null` keeps the
  /// alternating background.
  final Color? Function(int index)? rowColor;

  @override
  Widget build(BuildContext context) {
    assert(rows.every((cells) => cells.length == columns.length), 'Every row needs one cell per column.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++)
              ColoredBox(
                // Rows 2, 4, …: the subtle alternating background, edge to edge.
                color: rowColor?.call(i) ?? (i.isOdd ? JitanColors.tableStripe : JitanColors.surface),
                child: onRowTap == null
                    ? JitanTableRow(columns: columns, cells: rows[i])
                    : JitanTappableRow(
                        onTap: () => onRowTap!(i),
                        child: JitanTableRow(columns: columns, cells: rows[i]),
                      ),
              ),
          ],
        );
        final maxHeight = this.maxHeight;
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              JitanTableHeaderRow(columns: columns),
              if (maxHeight == null)
                body
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight - JitanDimensions.tableHeaderHeight),
                  child: SingleChildScrollView(child: body),
                ),
            ],
          ),
        );
        return constraints.maxWidth < minWidth
            ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: table)
            : table;
      },
    );
  }
}

/// A table row that opens something: hover highlight, keyboard focusable.
class JitanTappableRow extends StatelessWidget {
  const JitanTappableRow({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, hoverColor: JitanColors.tableHover, child: child),
        ),
      );
}

/// The warm-gray heading row of a [JitanDataTable], on its own so a page
/// can keep it in view while the rows scroll (a pinned sliver header).
class JitanTableHeaderRow extends StatelessWidget {
  const JitanTableHeaderRow({super.key, required this.columns});

  final List<JitanTableColumn> columns;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: JitanColors.tableHeader,
        child: JitanTableRow(
          height: JitanDimensions.tableHeaderHeight,
          columns: columns,
          cells: [
            for (final column in columns)
              Text(column.label, style: JitanTextStyles.tableHeader, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

/// One row of [JitanDataTable] cells laid out by [columns] (without its
/// background; the table, or a page building rows lazily, colours it).
class JitanTableRow extends StatelessWidget {
  const JitanTableRow({
    super.key,
    this.height = JitanDimensions.tableRowHeight,
    required this.columns,
    required this.cells,
  });

  final double height;
  final List<JitanTableColumn> columns;
  final List<Widget> cells;

  static Alignment _alignment(JitanColumnAlign align) => switch (align) {
        JitanColumnAlign.start => Alignment.centerLeft,
        JitanColumnAlign.center => Alignment.center,
        JitanColumnAlign.end => Alignment.centerRight,
      };

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JitanDimensions.tableHorizontalPadding),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                Expanded(
                  flex: columns[i].flex,
                  child: Padding(
                    // A little air between columns so text never touches.
                    padding: EdgeInsets.only(right: i == columns.length - 1 ? 0 : 12),
                    child: Align(
                      alignment: _alignment(columns[i].align),
                      child: DefaultTextStyle.merge(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        child: cells[i],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
