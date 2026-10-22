import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

Future<void> _pump(WidgetTester tester, Size size, {Widget? footer}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JitanListPage(
          top: const SizedBox(height: 200, child: Align(alignment: Alignment.bottomLeft, child: Text('Page title'))),
          list: [
            JitanSliverTable(
              columns: const [JitanTableColumn(label: 'Name', flex: 1), JitanTableColumn(label: 'Code', flex: 1)],
              rowCount: 80,
              cells: (i) => [Text('Row $i'), Text('C$i')],
              footer: footer,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop: the top stays, the heading row pins, rows are built lazily, the footer closes the table', (tester) async {
    await _pump(tester, const Size(1200, 800), footer: const Text('Showing 80 of 80'));
    final title = tester.getRect(find.text('Page title'));
    final heading = tester.getRect(find.text('Name'));
    expect(find.text('Row 60'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1500));
    await tester.pump();

    expect(tester.getRect(find.text('Page title')), title);
    expect(tester.getRect(find.text('Name')).top, heading.top);
    expect(find.text('Row 0'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pump();
    expect(find.text('Showing 80 of 80'), findsOneWidget);
  });

  testWidgets('a short window or a phone scrolls the whole page', (tester) async {
    for (final size in const [Size(1200, 560), Size(390, 844)]) {
      await _pump(tester, size);
      final title = tester.getRect(find.text('Page title'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -80));
      await tester.pump();
      expect(tester.getRect(find.text('Page title')).top, lessThan(title.top), reason: '$size');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('narrower than minWidth: one card that scrolls sideways', (tester) async {
    await _pump(tester, const Size(700, 900));

    expect(find.byType(JitanDataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
