import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

Widget _table(double width) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: const JitanDataTable(
              minWidth: 600,
              columns: [
                JitanTableColumn(label: 'Name', flex: 2),
                JitanTableColumn(label: 'Count', flex: 1),
              ],
              rows: [
                [Text('Almeco'), Text('48')],
                [Text('PCA'), Text('36')],
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders headers and cells', (tester) async {
    await tester.pumpWidget(_table(800));

    for (final text in ['Name', 'Count', 'Almeco', '48', 'PCA', '36']) {
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('splits width by flex', (tester) async {
    await tester.pumpWidget(_table(800));

    final name = tester.getTopLeft(find.text('Name')).dx;
    final count = tester.getTopLeft(find.text('Count')).dx;
    // 800 wide minus 2 × 20 padding = 760; Name takes 2/3.
    expect(count - name, closeTo(760 * 2 / 3, 1));
  });

  testWidgets('scrolls horizontally below its minimum width', (tester) async {
    await tester.pumpWidget(_table(400));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  testWidgets('does not scroll when wide enough', (tester) async {
    await tester.pumpWidget(_table(800));

    expect(find.byType(SingleChildScrollView), findsNothing);
  });

  Widget table({double width = 800, int rows = 3, double? maxHeight}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: JitanDataTable(
                maxHeight: maxHeight,
                columns: const [
                  JitanTableColumn(label: 'Name', flex: 3),
                  JitanTableColumn(label: 'Status', flex: 1),
                  JitanTableColumn(label: 'Actions', flex: 1, align: JitanColumnAlign.end),
                ],
                rows: [
                  for (var i = 0; i < rows; i++)
                    [
                      Text('Row $i'),
                      const JitanStatusLabel(label: 'Active', isPositive: true),
                      JitanRowActionsButton(tooltip: 'Row actions', onPressed: () {}),
                    ],
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('header and alternating rows fill the full width; rows are 44 px; no grid lines', (tester) async {
    await tester.pumpWidget(table());

    final boxes = tester.widgetList<ColoredBox>(find.descendant(of: find.byType(JitanDataTable), matching: find.byType(ColoredBox))).toList();
    expect([for (final b in boxes) b.color], [JitanColors.tableHeader, JitanColors.surface, JitanColors.tableStripe, JitanColors.surface]);
    for (final box in find.descendant(of: find.byType(JitanDataTable), matching: find.byType(ColoredBox)).evaluate()) {
      expect(tester.getSize(find.byWidget(box.widget)).width, 800, reason: 'edge to edge');
    }
    expect(tester.getSize(find.byWidget(boxes[1])).height, JitanDimensions.tableRowHeight);
    expect(JitanDimensions.tableRowHeight, 44);
    expect(find.descendant(of: find.byType(JitanDataTable), matching: find.byType(Divider)), findsNothing);
  });

  testWidgets('the status dot sits on the same line as its label, 8 px before it', (tester) async {
    await tester.pumpWidget(table(rows: 1));

    final label = tester.getRect(find.text('Active'));
    final dot = tester.getRect(find.descendant(of: find.byType(JitanStatusLabel), matching: find.byType(Container)));
    expect(dot.center.dy, closeTo(label.center.dy, 1));
    expect(label.left - dot.right, 8);
  });

  testWidgets('the actions column is right-aligned', (tester) async {
    await tester.pumpWidget(table(rows: 1));

    final button = tester.getRect(find.byType(JitanRowActionsButton));
    expect(800 - JitanDimensions.tableHorizontalPadding - button.right, lessThan(1));
  });

  testWidgets('a short table fits its rows; a long one scrolls its rows under the header', (tester) async {
    await tester.pumpWidget(table(rows: 2, maxHeight: 300));
    expect(tester.getSize(find.byType(JitanDataTable)).height, JitanDimensions.tableHeaderHeight + 2 * JitanDimensions.tableRowHeight);

    await tester.pumpWidget(table(rows: 20, maxHeight: 300));
    expect(tester.getSize(find.byType(JitanDataTable)).height, 300);
    expect(find.text('Name'), findsOneWidget, reason: 'header stays');
  });

  testWidgets('long text is cut with an ellipsis instead of overlapping the next column', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          child: JitanDataTable(
            columns: const [JitanTableColumn(label: 'Name', flex: 1), JitanTableColumn(label: 'Other', flex: 1)],
            rows: [
              [Text('A very long name ' * 20), const Text('Next')],
            ],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.textContaining('A very long')).right, lessThanOrEqualTo(tester.getRect(find.text('Next')).left));
  });
}
