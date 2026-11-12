import 'package:employee_mobile/src/activity/activity_controller.dart';
import 'package:employee_mobile/src/activity/choose_project_screen.dart';
import 'package:employee_mobile/src/activity/switch_activity_screen.dart';
import 'package:employee_mobile/src/home/home_project_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

final _since = DateTime.utc(2026, 10, 22, 6);
final _towers = MyProject(id: 1, name: 'P-1057 Cooling towers', isClient: true, placeName: 'Engis', lastUsed: _since);
const _workshop = MyProject(id: 2, name: 'P-0990 Clean the workshop', isClient: false, placeName: 'Almeco');
const _roof = MyProject(id: 3, name: 'P-1071 Roof repairs', isClient: true, placeName: 'Tournai');

class _FakeActivityApi implements ActivityApi {
  _FakeActivityApi(this.answer);

  MyActivity answer;
  ApiClientException? fail;
  final switches = <SwitchActivityRequest>[];

  @override
  Future<MyActivity> mine() async {
    if (fail case final failure?) throw failure;
    return answer;
  }

  @override
  Future<MyActivity> registerTrip(TripRequest request) async => answer;

  @override
  Future<MyActivity> switchTo(SwitchActivityRequest request) async {
    if (fail case final failure?) throw failure;
    switches.add(request);
    return answer;
  }
}

MyActivity _on(MyProject? project, {ActivityKind kind = ActivityKind.clientOnSite}) => MyActivity(
  enabled: true,
  current: CurrentActivity(kind: kind, since: _since, project: project),
  projects: [_towers, _workshop, _roof],
  companies: const [MyCompany(id: 7, name: 'Almeco', isDefault: true)],
);

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(theme: JitanTheme.light(), home: child),
    ),
  );
  await tester.pump();
}

void main() {
  test('switched off, or nothing to show: no card', () async {
    final off = ActivityController(_FakeActivityApi(MyActivity.disabled));
    await off.load();
    expect(off.showsCard, isFalse);

    final nothing = ActivityController(
      _FakeActivityApi(const MyActivity(enabled: true, projects: [], companies: [MyCompany(id: 7, name: 'Almeco', isDefault: true)])),
    );
    await nothing.load();
    expect(nothing.showsCard, isFalse);
  });

  test('a saved switch tells Home, so the totals follow', () async {
    var told = 0;
    final controller = ActivityController(_FakeActivityApi(_on(_towers)), onSwitched: () => told++);

    await controller.switchTo(kind: ActivityKind.transport, projectId: _towers.id);

    expect(told, 1);
  });

  test('a failed load keeps Home working', () async {
    final api = _FakeActivityApi(_on(_towers))..fail = const ApiClientException.network('offline');
    final controller = ActivityController(api);

    await controller.load();

    expect(controller.showsCard, isFalse);
  });

  testWidgets('the Home project row shows the project and what they do on it (Figma 1585:2)', (tester) async {
    var switched = 0;
    await _show(
      tester,
      Scaffold(
        body: HomeProjectRow(
          activity: CurrentActivity(kind: ActivityKind.clientOnSite, since: _since, project: _towers),
          onSwitch: () => switched++,
        ),
      ),
    );

    expect(find.text('P-1057 Cooling towers'), findsOneWidget);
    expect(find.text('Client · On site'), findsOneWidget);
    await tester.tap(find.text('Switch'));
    expect(switched, 1);
  });

  testWidgets('no project: says so, and they can still switch', (tester) async {
    await _show(tester, Scaffold(body: HomeProjectRow(activity: null, onSwitch: () {})));

    expect(find.text('No project'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
  });

  group('switch', () {
    Future<(_FakeActivityApi, ActivityController)> open(WidgetTester tester, MyActivity activity) async {
      final api = _FakeActivityApi(activity);
      final controller = ActivityController(api, clock: () => _since.add(const Duration(hours: 2)));
      await controller.load();
      await _show(tester, SwitchActivityScreen(controller: controller));
      return (api, controller);
    }

    testWidgets('nothing changed: the button waits; a change says what it will do (Figma 1588:2)', (tester) async {
      await open(tester, _on(_towers));

      final button = tester.widget<JitanMobileButton>(find.byType(JitanMobileButton));
      expect(button.onPressed, isNull);
      expect(button.label, 'Switch');
      expect(find.text('What are you working on?'), findsOneWidget);

      await tester.tap(find.text('Transport'));
      await tester.pump();
      expect(tester.widget<JitanMobileButton>(find.byType(JitanMobileButton)).label, 'Switch to Transport');
    });

    testWidgets('a client project offers its activities and transport', (tester) async {
      await open(tester, _on(_towers));

      expect(find.text('Transport'), findsOneWidget);

      expect(find.text('Client · In-house'), findsOneWidget);
      expect(find.text('Internal work'), findsOneWidget);
    });

    testWidgets('choosing sends the project, the activity and the moment', (tester) async {
      final (api, _) = await open(tester, _on(_towers));

      await tester.tap(find.text('Client · In-house'));
      await tester.pump();
      await tester.tap(find.byType(JitanMobileButton));
      await tester.pump();

      expect(api.switches.single.kind, ActivityKind.clientInHouse);
      expect(api.switches.single.projectId, _towers.id);
      expect(api.switches.single.at, _since.add(const Duration(hours: 2)));
    });

    testWidgets('the project field opens Choose a project; the chosen one is sent', (tester) async {
      final (api, _) = await open(tester, _on(_towers));

      await tester.tap(find.text('P-1057 Cooling towers').last);
      await tester.pumpAndSettle();
      expect(find.text('Choose a project'), findsOneWidget);
      await tester.tap(find.text('P-0990 Clean the workshop'));
      await tester.pumpAndSettle();

      expect(find.text('Our workshop · Almeco'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Client · In-house'), findsNothing, reason: 'internal work has no client activities');
      await tester.tap(find.text('Internal work'));
      await tester.pump();
      await tester.tap(find.byType(JitanMobileButton));
      await tester.pump();

      expect((api.switches.single.kind, api.switches.single.projectId), (ActivityKind.internal, _workshop.id));
      expect(find.text('Switch to P-0990 Clean the workshop'), findsNothing, reason: 'the switch closed the page');
    });

    testWidgets('a refused switch says so and stays', (tester) async {
      final (api, _) = await open(tester, _on(_towers));
      api.fail = const ApiClientException.network('offline');

      await tester.tap(find.text('Internal work'));
      await tester.pump();
      await tester.tap(find.byType(JitanMobileButton));
      await tester.pump();
      await tester.pump();

      expect(find.text('The switch wasn’t saved'), findsOneWidget);
    });
  });

  test('one kind of work alone is no breakdown', () {
    expect(const ActivityBreakdown(clientMinutes: 60).isMixed, isFalse);
    expect(const ActivityBreakdown(clientMinutes: 60, transportMinutes: 5).isMixed, isTrue);
  });

  group('Choose a project (Figma 1588:2)', () {
    testWidgets('Recent first, "Now" on the current one, then all projects', (tester) async {
      await _show(tester, ChooseProjectScreen(projects: [_towers, _workshop, _roof], currentId: _towers.id));

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('All projects'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('Client site · Tournai'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('P-1057 Cooling towers')).dy,
        lessThan(tester.getTopLeft(find.text('P-1071 Roof repairs')).dy),
      );
    });

    testWidgets('search finds the SAP number or the name, and says when nothing matches', (tester) async {
      await _show(tester, ChooseProjectScreen(projects: [_towers, _workshop, _roof]));

      await tester.enterText(find.byType(TextField), 'p-1071');
      await tester.pump();
      expect(find.text('P-1071 Roof repairs'), findsOneWidget);
      expect(find.text('P-1057 Cooling towers'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nothing like it');
      await tester.pump();
      expect(find.text('No projects match “nothing like it”.'), findsOneWidget);
    });

    testWidgets('no projects yet says so', (tester) async {
      await _show(tester, const ChooseProjectScreen(projects: []));
      expect(find.text('No projects yet. HR adds them, and they appear here.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
