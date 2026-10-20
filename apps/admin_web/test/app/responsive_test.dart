import 'package:admin_web/src/companies/companies_screen.dart';
import 'package:admin_web/src/groups/group_page.dart';
import 'package:admin_web/src/groups/groups_screen.dart';
import 'package:admin_web/src/schedules/schedule_form_fields.dart';
import 'package:admin_web/src/schedules/schedules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_companies_api.dart';
import '../support/fake_group_apis.dart';
import '../support/fake_schedules_api.dart';

/// Every page and dialog works from a phone to a wide screen: nothing
/// overflows, nothing is wider than the window.
const _widths = [390.0, 820.0, 1440.0, 2400.0];

Future<void> _pump(WidgetTester tester, double width, Widget page) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: JitanWebShell(
          sidebar: JitanWebSidebar(
            selectedPath: '/',
            onNavigate: (_) {},
            destinations: const [JitanNavDestination(label: 'Schedules', path: '/')],
          ),
          child: page,
        ),
      ),
    ),
  );
}

void _fitsTheWindow(WidgetTester tester, double width, String what) {
  final error = tester.takeException();
  if (error is FlutterError) debugPrint(error.toStringDeep());
  expect(error, isNull, reason: '$what at $width px: no overflow');
  for (final finder in [find.byType(JitanPrimaryButton), find.byType(JitanSelectField<int?>), find.byType(JitanSearchField)]) {
    for (final element in finder.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.right, lessThanOrEqualTo(width + 0.5), reason: '$what at $width px: ${element.widget.runtimeType} inside the window');
    }
  }
}

void main() {
  final blue = groupSchedule(1, 'Blue collar', work: workDays([1, 2, 3, 4, 5], '07:30', '17:30'), breakDays: breaks([1, 2, 3, 4, 5], '12:00', 15));
  final white = groupSchedule(2, 'White collar', status: GroupScheduleStatus.noSchedule);

  for (final width in _widths) {
    testWidgets('Schedules page at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([blue, white]);
      await tester.pump();

      _fitsTheWindow(tester, width, 'Schedules');
      expect(find.text('Blue collar · Work hours'), findsOneWidget);
    });

    testWidgets('Companies page at $width px', (tester) async {
      final api = FakeCompaniesApi();
      await _pump(tester, width, CompaniesScreen(api: api));
      api.succeed([company(1, 'Almeco', employees: 4), company(2, 'PCA', employees: 2)]);
      await tester.pump();

      _fitsTheWindow(tester, width, 'Companies');
    });

    testWidgets('the schedule wizard, every step, at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([blue, white]);
      await tester.pump();
      await tester.tap(find.text('Add schedule'));
      await tester.pump();
      api.succeedOptions();
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard step 1');

      tester.widget<JitanSelectField<int>>(find.widgetWithText(JitanSelectField<int>, 'Employee group *')).onChanged!(2);
      await tester.pump();
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard step 2');

      await tester.tap(find.text('Mon–Fri'));
      await tester.pump();
      await tester.tap(find.text('Same hours every working day'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard step 2, hours per day');
      for (final field in tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList().asMap().entries) {
        field.value.onChanged!(field.key.isEven ? '08:00' : '16:00');
      }
      tester.widget<JitanSelectField<int>>(find.widgetWithText(JitanSelectField<int>, 'Length')).onChanged!(30);
      await tester.pump();
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard step 3');

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'wizard review');
      expect(find.text('Review schedule'), findsOneWidget);
    });

    testWidgets('Groups page and Create group at $width px', (tester) async {
      final groups = FakeGroupManagementApi([groupOverview(1, 'Blue collar', employees: 64), groupOverview(2, 'White collar')]);
      final members = FakeGroupMembersApi()..pool.add(member(11, 'Fabian', 'Peeters', 'FPT', groups: ['White collar']));
      final schedules = FakeSchedulesApi();
      await _pump(tester, width, GroupsScreen(groupsApi: groups, membersApi: members, schedulesApi: schedules));
      await tester.pump();
      schedules.succeedList([blue, white]);
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Groups');

      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add group'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Create group, step 1');
      await tester.enterText(find.byType(TextField).last, 'Drivers');
      await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Create group'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Create group, step 2');
    });

    testWidgets('a group page at $width px', (tester) async {
      final groups = FakeGroupManagementApi([groupOverview(1, 'Blue collar', employees: 1)]);
      final members = FakeGroupMembersApi()
        ..byGroup[1] = [member(11, 'Fabian', 'Peeters', 'FPT', companies: ['Almeco', 'PCA'], groups: ['Blue collar', 'White collar'])];
      final schedules = FakeSchedulesApi();
      await _pump(tester, width, GroupPage(groupId: 1, groupsApi: groups, membersApi: members, schedulesApi: schedules));
      await tester.pump();
      await tester.pump();
      schedules.succeedList([blue, white]);
      await tester.pumpAndSettle();

      _fitsTheWindow(tester, width, 'group page');
      expect(find.text('Fabian Peeters · FPT'), findsOneWidget);
    });

    testWidgets('Manage schedules and Remove at $width px', (tester) async {
      final api = FakeSchedulesApi();
      await _pump(tester, width, SchedulesScreen(api: api));
      api.succeedList([blue, white]);
      await tester.pump();

      await tester.ensureVisible(find.byTooltip('Schedule actions').first);
      await tester.tap(find.byTooltip('Schedule actions').first);
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Manage schedules');
      await tester.tap(find.text('Remove schedule'));
      await tester.pumpAndSettle();
      _fitsTheWindow(tester, width, 'Remove schedule?');
    });
  }
}
