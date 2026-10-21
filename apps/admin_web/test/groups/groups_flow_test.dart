import 'package:admin_web/src/app/admin_app.dart';
import 'package:admin_web/src/groups/employee_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_group_apis.dart';
import '../support/fake_schedules_api.dart';
import '../support/test_services.dart';

final _blue = groupSchedule(1, 'Blue collar', work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'), breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30));
final _drivers = groupSchedule(3, 'Drivers', status: GroupScheduleStatus.noSingleGroupEmployees);
final _white = groupSchedule(2, 'White collar', status: GroupScheduleStatus.noSchedule);

TestServices _fakes() {
  final fakes = TestServices();
  fakes.groupManagement.groups.addAll([
    groupOverview(1, 'Blue collar', employees: 64),
    groupOverview(2, 'White collar', employees: 60),
    groupOverview(3, 'Drivers', employees: 0),
    groupOverview(4, 'Old', active: false),
  ]);
  fakes.groupMembers.pool.addAll([
    member(11, 'Fabian', 'Peeters', 'FPT', groups: ['White collar']),
    member(12, 'Kevin', 'De Vos', 'KDV', companies: ['PCA']),
  ]);
  return fakes;
}

Future<void> _pump(WidgetTester tester, TestServices fakes, String location) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TranslationScope(
    translations: Translations.english(),
    child: AdminApp(services: fakes.services, initialLocation: location),
  ));
  await tester.pump();
  fakes.schedules.succeedList([_blue, _white, _drivers]);
  await tester.pumpAndSettle();
}

Future<void> _tapPrimary(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(JitanPrimaryButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the list: name, employees, schedule, status; search and status filter', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    expect(find.text('Employee groups'), findsWidgets);
    expect(find.text('Blue collar'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('Mon–Fri 08:00–16:30'), findsOneWidget);
    expect(find.text('No schedule yet'), findsNWidgets(2), reason: 'White collar, and Old (deactivated)');
    expect(find.text('No schedule of its own'), findsOneWidget, reason: 'Drivers: nobody only in it');
    expect(find.text('Inactive'), findsOneWidget, reason: 'Old');

    await tester.enterText(find.byType(TextField).first, 'driv');
    await tester.pump();
    expect(find.text('Blue collar'), findsNothing);
    expect(find.text('Drivers'), findsOneWidget);
  });

  testWidgets('Create group: the name, then employees from every company; then the group page', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    await _tapPrimary(tester, 'Add group');
    expect(find.text('Create group'), findsWidgets);
    await _tapPrimary(tester, 'Create group');
    expect(find.text('Enter a name.'), findsOneWidget, reason: 'checked before sending');
    expect(fakes.groupManagement.calls.where((c) => c.startsWith('create')), isEmpty);

    await tester.enterText(find.byType(TextField).last, '  Van drivers ');
    await _tapPrimary(tester, 'Create group');
    expect(fakes.groupManagement.calls, contains('create Van drivers'));
    expect(find.byType(EmployeePicker), findsOneWidget, reason: 'step 2');
    expect(find.text('No other groups'), findsOneWidget, reason: 'the groups of each employee (1354:7)');

    await tester.tap(find.text('Fabian Peeters · FPT'));
    await tester.pump();
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add (2)'));
    await tester.pump();
    await tester.pump();
    expect(fakes.groupMembers.calls, contains('add 104 11,12'));
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(find.text('Group Van drivers created.'), findsOneWidget);
    expect(find.text('Manage employees and group working hours.'), findsOneWidget, reason: 'on the group page now');
    expect(find.text('Fabian Peeters · FPT'), findsOneWidget);
  });

  testWidgets('a duplicate name is shown under the field', (tester) async {
    final fakes = _fakes();
    fakes.groupManagement.failNext =
        const ApiClientException.server(409, ApiError(code: ApiErrorCode.duplicateGroupName, message: 'x', field: 'name'));
    await _pump(tester, fakes, '/groups');

    await _tapPrimary(tester, 'Add group');
    await tester.enterText(find.byType(TextField).last, 'Blue collar');
    await _tapPrimary(tester, 'Create group');

    expect(find.text('A group with this name already exists.'), findsOneWidget);
  });

  testWidgets('Manage group: rename; deactivate a group with employees is refused with the reason', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    await tester.tap(find.byTooltip('Group actions').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate group'));
    await tester.pumpAndSettle();
    expect(find.text('Cannot deactivate group'), findsOneWidget);
    expect(find.text('White collar · 60 employees'), findsOneWidget);
    expect(find.text('Remove or reassign all 60 employees before deactivating this group.'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Manage employees →'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Manage employees and group working hours.'), findsOneWidget, reason: 'on the group page');
    await tester.tap(find.text('Groups').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Group actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Blue');
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Save changes'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(fakes.groupManagement.calls, contains('rename 1 Blue'));
    expect(find.text('Group renamed to Blue.'), findsOneWidget);
  });

  testWidgets('the group page: members with their companies; remove; nobody only in it means no hours of its own', (tester) async {
    final fakes = _fakes();
    fakes.groupMembers.byGroup[3] = [member(11, 'Fabian', 'Peeters', 'FPT', groups: ['Drivers', 'White collar'])];
    await _pump(tester, fakes, '/groups/3');

    expect(find.text('Drivers'), findsWidgets);
    expect(find.text('Fabian Peeters · FPT'), findsOneWidget);
    expect(find.text('No employee has this as their only group, so the group has no work hours of its own.'), findsOneWidget);

    await tester.tap(find.text('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Remove from group?'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(fakes.groupMembers.calls, contains('remove 3 11'));
    expect(find.text('No employees in this group yet.'), findsOneWidget);
    expect(find.text('Add an employee whose only group is this one. The work hours are kept on those employees.'), findsOneWidget);
  });

  testWidgets('the group page opens the schedule wizard with the group already chosen', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/2');

    expect(find.text('No work hours yet.'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Set work hours'));
    await tester.pump();
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();

    expect(find.text('Create schedule'), findsOneWidget, reason: 'a new schedule, not an edit');
    expect(find.text('White collar'), findsWidgets, reason: 'chosen');
    expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Continue')).onPressed, isNotNull);
  });

  testWidgets('a configured group shows its hours and break', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/1');

    expect(find.text('Mon–Fri 08:00–16:30 · ±5 min · start Up · 15 min, finish Down · 15 min'), findsOneWidget);
    expect(find.text('Mon–Fri · 30 min'), findsOneWidget);
    expect(find.widgetWithText(JitanPrimaryButton, 'Edit work hours'), findsOneWidget);
  });
}
