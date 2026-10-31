import 'package:employee_mobile/src/activity/activity_controller.dart';
import 'package:employee_mobile/src/activity/current_project_card.dart';
import 'package:employee_mobile/src/activity/my_projects_screen.dart';
import 'package:employee_mobile/src/activity/switch_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

const _towers = MyProject(id: 1, name: 'Cooling towers', companyId: 7, companyName: 'Almeco', isClient: true, isCurrent: true);
const _workshop = MyProject(id: 2, name: 'Clean the workshop', companyId: 7, companyName: 'Almeco', isClient: false, isCurrent: true);
const _old = MyProject(id: 3, name: 'Motor testing', companyId: 8, companyName: 'PCA', isClient: false, isCurrent: false);
final _since = DateTime.utc(2026, 10, 22, 6);

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
  Future<MyActivity> switchTo(SwitchActivityRequest request) async {
    if (fail case final failure?) throw failure;
    switches.add(request);
    return answer;
  }
}

MyActivity _on(MyProject? project, {ActivityKind kind = ActivityKind.clientOnSite}) => MyActivity(
  enabled: true,
  current: CurrentActivity(kind: kind, since: _since, project: project),
  projects: const [_towers, _workshop, _old],
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
    expect((nothing.showsCard, nothing.showsCompanies), (false, false));
  });

  test('a failed load keeps Home working', () async {
    final api = _FakeActivityApi(_on(_towers))..fail = const ApiClientException.network('offline');
    final controller = ActivityController(api);

    await controller.load();

    expect(controller.showsCard, isFalse);
  });

  testWidgets('the card shows the project and what they do on it', (tester) async {
    await _show(
      tester,
      Scaffold(
        body: CurrentProjectCard(
          activity: CurrentActivity(kind: ActivityKind.clientOnSite, since: _since, project: _towers),
          onSwitch: () {},
          onProjects: () {},
        ),
      ),
    );

    expect(find.text('Cooling towers'), findsOneWidget);
    expect(find.text('Client project · Almeco'), findsOneWidget);
    expect(find.text('Client · On site'), findsOneWidget);
  });

  testWidgets('no project: says so, and they can still choose one', (tester) async {
    await _show(tester, Scaffold(body: CurrentProjectCard(activity: null, onSwitch: () {}, onProjects: () {})));

    expect(find.text('No project'), findsOneWidget);
    expect(find.text('Switch activity'), findsOneWidget);
  });

  group('switch', () {
    Future<(_FakeActivityApi, ActivityController)> open(WidgetTester tester, MyActivity activity) async {
      final api = _FakeActivityApi(activity);
      final controller = ActivityController(api, clock: () => _since.add(const Duration(hours: 2)));
      await controller.load();
      await _show(tester, SwitchActivityScreen(controller: controller));
      return (api, controller);
    }

    testWidgets('nothing changed: the button waits', (tester) async {
      await open(tester, _on(_towers));

      final button = tester.widget<JitanMobileButton>(find.byType(JitanMobileButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('a client project offers its three activities', (tester) async {
      await open(tester, _on(_towers));

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

    testWidgets('a refused switch says so and stays', (tester) async {
      final (api, _) = await open(tester, _on(_towers));
      api.fail = const ApiClientException.network('offline');

      await tester.tap(find.text('Internal work'));
      await tester.pump();
      await tester.tap(find.byType(JitanMobileButton));
      await tester.pump();
      await tester.pump();

      expect(find.text('The switch could not be saved.'), findsOneWidget);
    });
  });

  testWidgets('My projects: current and earlier; none says so', (tester) async {
    await _show(tester, const MyProjectsScreen(projects: [_towers, _old]));

    expect(find.text('Almeco · Active'), findsOneWidget);
    expect(find.text('PCA · Previously assigned'), findsOneWidget);

    await _show(tester, const MyProjectsScreen(projects: []));
    expect(find.text('No projects yet.'), findsOneWidget);
  });
}
