import 'package:employee_mobile/src/app/employee_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_jitan_server.dart';

/// My QR (Figma 50:67): the Terminal QR from the bar.
void main() {
  late TestHarness h;

  setUp(() {
    h = TestHarness(clock: () => DateTime(2026, 10, 22, 9));
    h.server.issuedTokens.add('stored-token');
    h.store.values
      ..['session.token'] = 'stored-token'
      ..['session.expiresAt'] = '2099-01-01T00:00:00.000Z';
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EmployeeApp(services: h.services));
    await settle(tester);
    await tester.tap(find.text('QR'));
    await settle(tester);
  }

  testWidgets('the QR tab shows the Terminal QR, fetched with the session, never stored', (tester) async {
    await open(tester);

    expect(find.text('My QR'), findsOneWidget);
    expect(find.text('Present this code at a Jitan Terminal.'), findsOneWidget);
    expect(find.text('Disan Ssebowa'), findsOneWidget);
    expect(tester.widget<JitanQrCode>(find.byType(JitanQrCode)).data, terminalQr);
    expect(find.text('Ready to scan'), findsOneWidget);
    expect(find.text(terminalQr), findsNothing, reason: 'shown only as a QR');
    expect(h.server.requestsTo('/me/terminal-qr').single.headers['authorization'], 'Bearer stored-token');
    expect(h.store.values.values, isNot(contains(terminalQr)), reason: 'never kept on the phone');
  });

  testWidgets('an account without a QR says to ask HR', (tester) async {
    h.server.myTerminalQr = null;
    await open(tester);
    expect(find.text('Your account has no QR yet. Ask HR.'), findsOneWidget);
  });
}
