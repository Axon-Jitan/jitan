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

  testWidgets('a search can find nothing, and says so calmly (Figma 1545:830)', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No matching terminals'), findsOneWidget);
    expect(find.text('Try another name.'), findsOneWidget);
  });

  testWidgets('Inactive with none says every terminal is in use; All shows them again', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Inactive'));
    await tester.pumpAndSettle();
    expect(find.text('No inactive terminals'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Front desk'), findsOneWidget);
  });

  testWidgets('nothing yet: one line and Add terminal, no search (Figma 1545:955)', (tester) async {
    api.terminals = [];
    await pump(tester);
    expect(find.text('No terminals yet'), findsOneWidget);
    expect(find.byType(JitanSearchField), findsNothing);
    expect(find.widgetWithText(JitanPrimaryButton, 'Add terminal'), findsOneWidget);
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

  testWidgets('a workshop terminal is its own kind, and works like an office one (D18)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add terminal'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workshop terminal'));
    await tester.pumpAndSettle();
    expect(find.text('Include the number plate, so drivers find their van.'), findsNothing);

    await tester.enterText(find.byType(TextField).at(1), 'Almeco workshop');
    await tester.enterText(find.byType(TextField).at(2), 'R9TW40WORK');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(api.created.single.typeId, workshop.id);
    await tester.tap(find.text('Finish later'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
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

  testWidgets('no Remove: Deactivate, said once it is done, and the terminal stays as Inactive', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Van 1-DEF-456'));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsNothing);

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(api.calls, ['deactivate 2']);
    expect(find.text('Van 1-DEF-456 deactivated.'), findsOneWidget);
    expect(find.text('Van 1-DEF-456'), findsOneWidget);
    expect(find.text('Inactive'), findsNWidgets(2), reason: 'the row and the pill');
  });

  testWidgets('an inactive terminal says what that means, and Reactivate needs no question (Figma 1545:408)', (tester) async {
    api.terminals = [officeTerminal(id: 4, name: 'Old tablet', status: TerminalStatus.inactive)];
    await pump(tester);
    await tester.tap(find.text('Old tablet'));
    await tester.pumpAndSettle();

    expect(find.text('Employees can’t scan on this tablet. Reactivate it to use it again.'), findsOneWidget);
    expect(find.text('Reconnect'), findsNothing);
    expect(find.text('Connect'), findsNothing);

    await tester.tap(find.text('Reactivate'));
    await tester.pumpAndSettle();
    expect(api.calls, ['reactivate 4']);
    expect(find.text('Old tablet reactivated.'), findsOneWidget);
  });

  testWidgets('Edit: Save waits for a change, and the save is said (Figma 1545:687)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Almeco Reception'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    JitanPrimaryButton save() => tester.widget(find.widgetWithText(JitanPrimaryButton, 'Save'));
    expect(save().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Almeco Reception'), 'Almeco front desk');
    await tester.pump();
    expect(save().onPressed, isNotNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(api.updated.single.$2.name, 'Almeco front desk');
    expect(find.text('Almeco Reception saved.'), findsOneWidget, reason: 'the fake answers with the stored terminal');
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
