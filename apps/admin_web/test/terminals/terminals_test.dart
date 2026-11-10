import 'package:admin_web/src/terminals/terminal_text.dart';
import 'package:admin_web/src/terminals/terminals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_terminals.dart';

void main() {
  final now = DateTime(2026, 11, 1, 9);
  late FakeTerminalsApi api;

  setUp(() {
    api = FakeTerminalsApi()
      ..terminals = [
        officeTerminal(lastSeen: now.subtract(const Duration(minutes: 2)).toUtc(), lastScan: DateTime(2026, 11, 1, 7, 12).toUtc()),
        officeTerminal(id: 2, name: 'Van 1-DEF-456', status: TerminalStatus.offline),
        officeTerminal(id: 3, name: 'Front desk', status: TerminalStatus.notConnected, connectionTag: null),
      ];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.web(),
          home: Scaffold(
            body: TerminalsScreen(api: api, clock: () => now),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the list: every status, when each was last seen, and how many', (tester) async {
    await pump(tester);

    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('2 min ago'), findsOneWidget);
    expect(find.text('3 terminals'), findsOneWidget);
  });

  testWidgets('no terminals yet says so, and a search can find nothing', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No terminals match your search.'), findsOneWidget);
  });

  testWidgets('Add terminal asks for what is missing and only then goes on to the QR', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add terminal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Give the terminal a name.'), findsOneWidget);
    expect(find.text('Give the serial number on the tablet’s label.'), findsOneWidget);
    expect(api.created, isEmpty);
  });

  testWidgets('Add terminal: a name, the kind and the serial number; no company (Figma 1507:126)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add terminal'));
    await tester.pumpAndSettle();

    expect(find.text('On the label on the back of the tablet.'), findsOneWidget);
    expect(find.text('Company'), findsNothing);
    await tester.enterText(find.byType(TextField).at(1), 'Workshop entrance');
    await tester.enterText(find.byType(TextField).at(2), ' R9TW40ABCDE ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.created.single.serialNumber, ' R9TW40ABCDE ', reason: 'the server trims');
    expect(api.created.single.typeId, office.id);
    await tester.tap(find.text('Finish later'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a vehicle says to put the number plate in the name (Figma 1507:280)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add terminal'));
    await tester.pumpAndSettle();
    expect(find.text('Include the number plate, so drivers find their van.'), findsNothing);

    await tester.tap(find.text('Vehicle terminal'));
    await tester.pumpAndSettle();

    expect(find.text('Include the number plate, so drivers find their van.'), findsOneWidget);
    expect(find.text('Number plate'), findsNothing);
  });

  testWidgets('Manage: the kind, the serial number and the last scan (Figma 1507:434)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Almeco Reception'));
    await tester.pumpAndSettle();

    expect(find.text('R9TW40-1'), findsOneWidget);
    expect(find.text('Last scan'), findsOneWidget);
    expect(find.text('07:12'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Deactivate asks first, and Cancel changes nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Almeco Reception'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();

    expect(find.text('Deactivate Almeco Reception?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
  });

  testWidgets('Remove asks first, and then it is gone', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Van 1-DEF-456'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(api.calls, ['remove 2']);
    expect(find.text('Van 1-DEF-456'), findsNothing);
  });

  testWidgets('a terminal never connected offers Connect, and waits for the tablet', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Front desk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump();

    expect(api.calls, ['qr 3']);
    expect(find.textContaining('Waiting for the tablet'), findsOneWidget);
    expect(find.byType(JitanQrCode), findsOneWidget);

    api.found = officeTerminal(id: 3, name: 'Front desk');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.text('Front desk is ready'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reconnecting: a tablet still checking in doesn’t count as the new one', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Almeco Reception'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconnect'));
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.textContaining('Waiting for the tablet'), findsOneWidget);
    await tester.tap(find.text('Finish later'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an expired code is no longer drawn, and a new one can be asked for', (tester) async {
    api.qrExpires = DateTime.now().toUtc().add(const Duration(seconds: 1));
    await pump(tester);
    await tester.tap(find.text('Front desk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pump();
    await tester.pump();

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1100)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('This code has expired'), findsOneWidget);
    expect(find.byType(JitanQrCode), findsNothing);

    api.qrExpires = DateTime.now().toUtc().add(const Duration(minutes: 10));
    await tester.tap(find.text('New code'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(JitanQrCode), findsOneWidget);
    await tester.tap(find.text('Finish later'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('last seen reads like a person would say it', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      TranslationScope(
        translations: Translations.english(),
        child: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(TerminalText.lastSeen(context, null, now), '—');
    expect(TerminalText.lastSeen(context, now, now), 'Now');
    expect(TerminalText.lastSeen(context, now.subtract(const Duration(minutes: 5)), now), '5 min ago');
    expect(TerminalText.lastSeen(context, DateTime(2026, 11, 1, 7, 30), now), '07:30');
    expect(TerminalText.lastSeen(context, DateTime(2026, 10, 31, 16, 42), now), 'Yesterday, 16:42');
    expect(TerminalText.lastSeen(context, DateTime(2026, 10, 28, 9, 12), now), '28 October, 09:12');
  });
}
