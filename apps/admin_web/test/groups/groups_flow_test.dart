import 'package:admin_web/src/app/admin_app.dart';
import 'package:admin_web/src/groups/employee_picker.dart';
import 'package:admin_web/src/schedules/schedule_form_fields.dart';
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

JitanPrimaryButton _primary(WidgetTester tester, String label) =>
    tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, label));

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

  testWidgets('Create group: name, employees (someone only in it), hours and break, saved together', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    await _tapPrimary(tester, 'Add group');
    expect(find.text('Set up an employee group in three steps.'), findsOneWidget);
    expect(_primary(tester, 'Continue').onPressed, isNull, reason: 'no name yet');
    await tester.enterText(find.byType(TextField).last, '  Van drivers ');
    await tester.pump();
    await _tapPrimary(tester, 'Continue');

    // Step 2: the list opens under "Select employees".
    expect(find.text('Select employees'), findsOneWidget);
    await tester.tap(find.byType(EmployeePicker));
    await tester.pumpAndSettle();
    expect(fakes.groupMembers.calls, contains('candidates new'), reason: 'the group does not exist yet');
    expect(find.text('No other groups'), findsOneWidget, reason: 'Kevin');
    await tester.tap(find.text('Fabian Peeters · FPT'));
    await tester.pump();
    expect(find.text('Selected: 0 employees who belong only to Van drivers.'), findsOneWidget);
    expect(_primary(tester, 'Continue').onPressed, isNull, reason: 'Fabian is also in White collar: the hours need someone only here');
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();
    expect(find.text('Selected: 1 employee who belongs only to Van drivers.'), findsOneWidget);
    await _tapPrimary(tester, 'Continue');

    // Step 3: work hours and break.
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();
    expect(find.text('Working days'), findsOneWidget);
    expect(_primary(tester, 'Create group').onPressed, isNull, reason: 'nothing typed yet');
    await tester.tap(find.text('Mon–Fri'));
    await tester.pump();
    final times = tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList();
    times[0].onChanged!('08:00');
    times[1].onChanged!('07:30');
    await tester.pump();
    expect(find.text('Finish must be after the start'), findsOneWidget);
    tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList()[1].onChanged!('16:30');
    await tester.enterText(find.byType(TextField).last, '20');
    await tester.pump();
    expect(find.text('Enter 15, 30, 45, 60 minutes.'), findsOneWidget, reason: 'the allowed break lengths');
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Create group'));
    await tester.pump();
    await tester.pump();

    expect(fakes.groupManagement.calls, contains('create Van drivers 11,12'));
    final sent = fakes.groupManagement.created!;
    expect(sent.schedule.breakMinutes, 30);
    expect([for (final d in sent.schedule.workHours.days) (d.start, d.finish)], List.filled(5, ('08:00', '16:30')));
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Group Van drivers created.'), findsOneWidget);
    expect(find.text('Manage employees and group working hours.'), findsOneWidget, reason: 'on the group page now');
  });

  testWidgets('a duplicate name found at the save is shown under the name, on step 1', (tester) async {
    final fakes = _fakes();
    fakes.groupManagement.failNext =
        const ApiClientException.server(409, ApiError(code: ApiErrorCode.duplicateGroupName, message: 'x', field: 'name'));
    await _pump(tester, fakes, '/groups');

    await _tapPrimary(tester, 'Add group');
    await tester.enterText(find.byType(TextField).last, 'Blue collar');
    await tester.pump();
    await _tapPrimary(tester, 'Continue');
    await tester.tap(find.byType(EmployeePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();
    await _tapPrimary(tester, 'Continue');
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon–Fri'));
    await tester.pump();
    final times = tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList();
    times[0].onChanged!('08:00');
    times[1].onChanged!('16:30');
    await tester.enterText(find.byType(TextField).last, '30');
    await tester.pump();
    await _tapPrimary(tester, 'Create group');

    expect(find.text('Group details'), findsWidgets, reason: 'back on step 1');
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

    expect(find.text('Mon–Fri 08:00–16:30 · Break 30 min'), findsOneWidget, reason: '1378:4');
    expect(find.widgetWithText(JitanPrimaryButton, 'Edit work hours'), findsOneWidget);
  });

  testWidgets('an empty group asks to confirm; an inactive group says so and offers Reactivate group', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    await tester.tap(find.byTooltip('Group actions').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate group'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Drivers?'), findsOneWidget, reason: '1378:186');
    expect(find.text('The group can no longer be assigned. You can reactivate it later.'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Deactivate'));
    await tester.pump();
    await tester.pump();
    expect(fakes.groupManagement.calls, contains('deactivate 3'));
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Old'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Inactive'), findsWidgets, reason: '1378:363');
    await tester.tap(find.text('Reactivate group →'));
    await tester.pump();
    await tester.pump();
    expect(fakes.groupManagement.calls, contains('reactivate 4'));
  });

  testWidgets('Create group step 2: clicks beside the list or outside the dialog change nothing', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');
    await _tapPrimary(tester, 'Add group');
    await tester.enterText(find.byType(TextField).last, 'Drivers');
    await tester.pump();
    await _tapPrimary(tester, 'Continue');

    await tester.tap(find.byType(EmployeePicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();

    await tester.tap(find.text('Set up an employee group in three steps.'));
    await tester.pumpAndSettle();
    expect(find.text('Kevin De Vos · KDV'), findsOneWidget, reason: 'the list stays open: the dialog does not jump');

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Create group'), findsWidgets, reason: 'a click outside does not close the dialog');
    expect(find.text('Selected: 1 employee who belongs only to Drivers.'), findsOneWidget, reason: 'nothing lost');
  });
}
