import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) => SizedBox.expand(child: Text('page', key: ValueKey(context = c))))),
    ));
    return context;
  }

  testWidgets('one next step: tapping it closes the toast and runs it', (tester) async {
    final context = await pump(tester);
    var opened = 0;
    showJitanToast(context, 'Proceq added', actionLabel: 'Add location', onAction: () => opened++);
    await tester.pumpAndSettle();

    expect(find.text('Proceq added'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('Add location'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(find.text('Proceq added'), findsNothing);
  });

  testWidgets('the newest replaces the one showing, and both fade', (tester) async {
    final context = await pump(tester);
    showJitanToast(context, 'Proceq added', actionLabel: 'Add location', onAction: () {});
    await tester.pumpAndSettle();
    showJitanToast(context, 'PCA deactivated');
    await tester.pumpAndSettle();

    expect(find.text('Proceq added'), findsNothing);
    expect(find.text('PCA deactivated'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('PCA deactivated'), findsNothing);
  });
}
