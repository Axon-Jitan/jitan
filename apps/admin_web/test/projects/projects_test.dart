import 'package:admin_web/src/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_locations.dart';
import '../support/fake_projects.dart';

void main() {
  final now = DateTime(2026, 11, 10, 15);
  late FakeProjectsApi api;
  late FakeLocationsApi locations;

  setUp(() {
    api = FakeProjectsApi()
      ..projects = [
        projectDetails(lastUsed: DateTime(2026, 11, 10, 9).toUtc()),
        projectDetails(id: 4, sapNumber: 'P-0990', name: 'Cleaning the workshop', workshopId: 1),
        projectDetails(id: 5, sapNumber: 'P-0871', name: 'Customer installation', active: false),
      ];
    locations = FakeLocationsApi()..locations.add(location(1, 'Almeco workshop'));
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
          home: Scaffold(body: ProjectsScreen(api: api, locationsApi: locations, maps: null, clock: () => now)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the list (1562:2): SAP number and name, the place, when last used and the status; a count and the pills', (tester) async {
    await pump(tester);

    expect(find.text('P-1042 Office refurbishment'), findsOneWidget);
    expect(find.text('Client site · Mouscron'), findsWidgets);
    expect(find.text('Our workshop · Almeco workshop'), findsOneWidget);
    expect(find.text('Inactive'), findsNWidgets(2), reason: 'the pill and the inactive project');
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('3 projects'), findsOneWidget, reason: 'the count under the title');

    await tester.tap(find.text('Inactive').first);
    await tester.pumpAndSettle();
    expect(find.text('P-0871 Customer installation'), findsOneWidget);
    expect(find.text('P-1042 Office refurbishment'), findsNothing);
  });

  testWidgets('search narrows by SAP number or name, and says when nothing matches', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'p-0990');
    await tester.pumpAndSettle();
    expect(find.text('P-0990 Cleaning the workshop'), findsOneWidget);
    expect(find.text('P-1042 Office refurbishment'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No matching projects'), findsOneWidget);
    expect(find.text('Try another name or SAP number.'), findsOneWidget);
  });

  testWidgets('nothing yet', (tester) async {
    api.projects = [];
    await pump(tester);
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.widgetWithText(JitanPrimaryButton, 'Add project'), findsOneWidget, reason: 'one button, not two');
  });

  testWidgets('a failure, with a retry', (tester) async {
    api.fail = const ApiClientException.network('down');
    await pump(tester);
    expect(find.text('Unable to load projects. Try again →'), findsOneWidget);
  });

  testWidgets('Add project at our workshop: SAP number, name and workshop, then it is saved (Figma 1512:305)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();
    expect(find.text('A client site: arriving there starts work on this project.'), findsOneWidget);

    await tester.tap(find.text('Our workshop'));
    await tester.pumpAndSettle();
    expect(find.text('Workshop'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'P-1100');
    await tester.enterText(find.byType(TextField).at(2), 'Painting');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add project').last);
    await tester.pumpAndSettle();

    expect(api.calls, ['create']);
    expect((api.saved.single.sapNumber, api.saved.single.name, api.saved.single.workshopId), ('P-1100', 'Painting', 1));
    expect(find.text('P-1100 Painting'), findsWidgets, reason: 'in the list, and in the toast');
    expect(find.text('P-1100 Painting added.'), findsOneWidget);
  });

  testWidgets('switching to our workshop keeps the pop-up one size (1562:350)', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();
    final popup = find.descendant(of: find.byType(Dialog), matching: find.byType(LayoutBuilder)).first;
    final first = tester.getSize(popup);
    await tester.tap(find.text('Our workshop'));
    await tester.pumpAndSettle();
    expect(tester.getSize(popup), first);
    expect(find.text('Almeco workshop · its own area'), findsOneWidget, reason: 'the only workshop, already chosen, on the map');
  });

  testWidgets('a client site can’t be saved before it has a street and a pin', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'P-1200');
    await tester.enterText(find.byType(TextField).at(2), 'Roof');
    await tester.pumpAndSettle();

    final add = tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Add project').last);
    expect(add.onPressed, isNull);
  });

  testWidgets('a row opens its project by name (1562:101); it keeps its kind; Save waits for a change; Deactivate asks first', (tester) async {
    await pump(tester);

    await tester.tap(find.text('P-0990 Cleaning the workshop'));
    await tester.pumpAndSettle();
    expect(find.text('P-0990 Cleaning the workshop'), findsWidgets, reason: 'the title');
    expect(find.text('Active · Our workshop · Changes apply right away.'), findsOneWidget);
    expect(find.text('Almeco workshop · its own area'), findsOneWidget, reason: 'the workshop on the map');
    expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Save')).onPressed, isNull, reason: 'nothing changed');
    await tester.tap(find.text('Client site'));
    await tester.pumpAndSettle();
    expect(find.text('Workshop'), findsOneWidget, reason: 'the kind is fixed once added');

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate P-0990 Cleaning the workshop?'), findsOneWidget, reason: '1562:605');
    expect(api.calls, isEmpty, reason: 'nothing before HR agrees');
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Deactivate'));
    await tester.pumpAndSettle();
    expect(api.calls, ['deactivate 4']);
    expect(find.text('P-0990 Cleaning the workshop deactivated.'), findsOneWidget);
  });

  testWidgets('an inactive project (1562:789) offers Reactivate, without asking', (tester) async {
    await pump(tester);
    await tester.tap(find.text('P-0871 Customer installation'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Inactive · Client site'), findsOneWidget);
    await tester.tap(find.text('Reactivate'));
    await tester.pumpAndSettle();
    expect(api.calls, ['reactivate 5']);
    expect(find.text('P-0871 Customer installation reactivated.'), findsOneWidget);
  });
}
