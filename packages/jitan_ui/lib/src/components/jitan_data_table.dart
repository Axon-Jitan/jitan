import 'package:flutter/widgets.dart';

import '../theme/jitan_dimensions.dart';
import '../theme/jitan_text_styles.dart';

/// A column of [JitanDataTable]. [flex] sets its share of the width.
class JitanTableColumn {
  const JitanTableColumn({required this.label, required this.flex});

  final String label;
  final int flex;
}

/// The borderless web table: bold muted header row, then evenly spaced rows.
///
/// Below [minWidth] the table scrolls horizontally instead of squashing.
class JitanDataTable extends StatelessWidget {
  const JitanDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 760,
  });

  final List<JitanTableColumn> columns;

  /// One list of cell widgets per row, in column order.
  final List<List<Widget>> rows;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    assert(rows.every((cells) => cells.length == columns.length), 'Every row needs one cell per column.');

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;
        final table = SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Row(
                height: JitanDimensions.tableHeaderHeight,
                columns: columns,
                cells: [
                  for (final column in columns) Text(column.label, style: JitanTextStyles.tableHeader),
                ],
              ),
              for (final cells in rows)
                _Row(height: JitanDimensions.tableRowHeight, columns: columns, cells: cells),
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

class _Row extends StatelessWidget {
  const _Row({required this.height, required this.columns, required this.cells});

  final double height;
  final List<JitanTableColumn> columns;
  final List<Widget> cells;

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
                  child: Align(alignment: Alignment.centerLeft, child: cells[i]),
                ),
            ],
          ),
        ),
      );
}
