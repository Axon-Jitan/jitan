import 'package:admin_web/src/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_auth.dart';
import '../support/fake_employees_api.dart';
import '../support/fake_locations.dart';
import '../support/fake_projects.dart';

Future<void> _pump(WidgetTester tester, FakeProjectsApi api, {FakeEmployeesApi? employees}) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: ProjectsScreen(
            api: api,
            companiesApi: AllCompaniesApi(),
            employeesApi: employees ?? FakeEmployeesApi(),
            locationsApi: FakeLocationsApi(),
          ),
        ),
      ),
      GoRoute(path: '/projects/:company/:id', builder: (context, state) => Text('page ${state.pathParameters['id']}')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp.router(theme: JitanTheme.web(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  FakeProjectsApi withProjects() => FakeProjectsApi()
    ..projects = [
      projectDetails(id: 1, name: 'Office refurbishment', reference: 'PRJ-001'),
      projectDetails(id: 2, name: 'Warehouse upgrade', companyId: 8, companyName: 'PCA', status: planned, reference: null),
    ];

  testWidgets('lists the projects, and search narrows them by name or reference', (tester) async {
    await _pump(tester, withProjects());

    expect(find.text('Office refurbishment'), findsOneWidget);
    expect(find.text('Warehouse upgrade'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'prj-001');
    await tester.pump();

    expect(find.text('Warehouse upgrade'), findsNothing);
    expect(find.text('Office refurbishment'), findsOneWidget);
  });

  testWidgets('nothing yet, and a failure with a retry', (tester) async {
    final api = FakeProjectsApi();
    await _pump(tester, api);
    expect(find.text('No projects yet.'), findsOneWidget);

    api.fail = const ApiClientException.network('offline');
    await _pump(tester, FakeProjectsApi()..fail = api.fail);
    expect(find.text('Unable to load projects. Try again →'), findsOneWidget);
  });

  testWidgets('a row opens the project', (tester) async {
    await _pump(tester, withProjects());

    await tester.tap(find.text('Warehouse upgrade'));
    await tester.pumpAndSettle();

    expect(find.text('page 2'), findsOneWidget);
  });

  testWidgets('the form asks for what is missing, and saves nothing', (tester) async {
    final api = FakeProjectsApi();
    await _pump(tester, api);

    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create & assign'));
    await tester.pumpAndSettle();

    expect(find.text('Give the project a name.'), findsOneWidget);
    expect(find.text('Choose a company.'), findsOneWidget);
    expect(find.text('Choose a type.'), findsOneWidget);
    expect(find.text('Choose the start date.'), findsOneWidget);
    expect(api.created, isEmpty);
  });

  testWidgets('Client address shows only for a client project', (tester) async {
    await _pump(tester, FakeProjectsApi());

    await tester.tap(find.text('Add project'));
    await tester.pumpAndSettle();
    expect(find.text('Client address'), findsNothing);

    await tester.tap(find.widgetWithText(JitanSelectField<int>, 'Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Client').last);
    await tester.pumpAndSettle();

    expect(find.text('Client address'), findsOneWidget);
  });
}
