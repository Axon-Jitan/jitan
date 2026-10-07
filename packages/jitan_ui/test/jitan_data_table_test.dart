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
}
