import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

void main() {
  testWidgets('renders at the requested size with a screen-reader label, never the raw value', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: JitanQrCode(data: 'SECRET-VALUE', semanticLabel: 'QR for Disan'))),
    ));

    expect(tester.getSize(find.byType(JitanQrCode)), const Size(320, 320));
    expect(find.bySemanticsLabel('QR for Disan'), findsOneWidget);
    expect(find.text('SECRET-VALUE'), findsNothing);
  });
}
