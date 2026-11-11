import 'package:admin_web/src/app/admin_app.dart';
import 'package:admin_web/src/schedules/schedule_form_fields.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

/// The text fields of the open dialog: the name first, then the search.
Finder _dialogField(int index) => find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).at(index);

/// Chooses the working days by their round buttons.
Future<void> _days(WidgetTester tester, List<String> names) async {
  for (final name in names) {
    await tester.tap(find.byTooltip(name));
    await tester.pump();
  }
}

/// Opens [employee]'s "Hours: …" choice and picks [option].
Future<void> _hoursFrom(WidgetTester tester, String option) async {
  await tester.tap(find.byType(JitanInlineSelect<bool>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the list (1554:2): name, employees, schedule, status; a count; search and the status pills', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    expect(find.text('Groups'), findsWidgets);
    expect(find.text('4 groups'), findsOneWidget);
    expect(find.text('Blue collar'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('Mon–Fri 08:00–16:30'), findsOneWidget);
    expect(find.text('No schedule yet'), findsNWidgets(2), reason: 'White collar, and Old (deactivated)');
    expect(find.text('No schedule of its own'), findsOneWidget, reason: 'Drivers: nobody only in it');
    expect(find.byTooltip('Group actions'), findsNothing, reason: 'a row opens the page, which holds the actions');

    await tester.tap(find.text('Inactive').first);
    await tester.pump();
    expect(find.text('Blue collar'), findsNothing);
    expect(find.text('Old'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField).first, 'driv');
    await tester.pump();
    expect(find.text('Blue collar'), findsNothing);
    expect(find.text('Drivers'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'nobody');
    await tester.pump();
    expect(find.text('No matching groups'), findsOneWidget);
    expect(find.text('Try another name.'), findsOneWidget);
  });

  testWidgets('nothing yet: a calm page with Add group (1558:104)', (tester) async {
    final fakes = TestServices();
    await _pump(tester, fakes, '/groups');

    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.widgetWithText(JitanPrimaryButton, 'Add group'), findsOneWidget, reason: 'one button, not two');
  });

  testWidgets('Create group: name and employees, hours, rules, review; saved together', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');

    await _tapPrimary(tester, 'Add group');
    for (final step in ['Group', 'Hours', 'Rules', 'Review']) {
      expect(find.text(step), findsWidgets, reason: step);
    }
    expect(_primary(tester, 'Continue').onPressed, isNull, reason: 'no name yet');
    await tester.enterText(_dialogField(0), '  Van drivers ');
    await tester.pump();
    expect(fakes.groupMembers.calls, contains('candidates new'), reason: 'the group does not exist yet');

    // Step 1: the employees, on the same step.
    await tester.tap(find.text('Fabian Peeters · FPT'));
    await tester.pump();
    expect(find.text('Also in White collar'), findsOneWidget);
    expect(
      find.text('Everyone keeps their current hours, so Van drivers needs no work hours now. You can set them later on the group page.'),
      findsOneWidget,
      reason: 'Fabian keeps White collar hours by default',
    );
    expect(_primary(tester, 'Create group').onPressed, isNotNull, reason: 'no hours to ask: the first step creates the group');
    expect(find.text('Hours: White collar'), findsOneWidget, reason: 'his choice, on his line');
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();
    expect(find.text('2 chosen'), findsOneWidget);
    await _hoursFrom(tester, 'Hours: Van drivers');
    await _tapPrimary(tester, 'Continue');

    // Step 2: work hours and break.
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();
    expect(find.text('Work days'), findsOneWidget);
    expect(find.text('Van drivers'), findsWidgets, reason: 'the name under the title');
    expect(find.text('Set hours later'), findsOneWidget, reason: 'hours are optional');
    expect(_primary(tester, 'Continue').onPressed, isNull, reason: 'no hours entered yet');
    await _days(tester, ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
    expect(_primary(tester, 'Continue').onPressed, isNull, reason: 'days chosen but no times yet');
    final times = tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList();
    times[0].onChanged!('08:00');
    times[1].onChanged!('07:30');
    await tester.pump();
    expect(find.text('Finish must be after the start'), findsOneWidget);
    tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList()[1].onChanged!('16:30');
    tester.widgetList<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>)).last.onChanged!(30);
    await tester.pump();
    await _tapPrimary(tester, 'Continue');

    // Step 3: tolerance and rounding.
    expect(find.text('Arrival tolerance'), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(ScheduleMinutesChip).first, matching: find.byType(TextField)), '99');
    await tester.pump();
    await _tapPrimary(tester, 'Continue');
    expect(find.textContaining('Enter 0 to'), findsOneWidget, reason: 'beyond the allowed tolerance');
    await tester.enterText(find.descendant(of: find.byType(ScheduleMinutesChip).first, matching: find.byType(TextField)), '5');
    await tester.pump();
    tester.widget<ScheduleRoundingSelect>(find.byType(ScheduleRoundingSelect).first).onChanged!(
      const ScheduleRounding(intervalMinutes: 15, roundUp: true),
    );
    await tester.pump();
    await _tapPrimary(tester, 'Continue');

    // Step 4: the review.
    expect(find.text('Mon–Fri'), findsOneWidget);
    expect(find.text('08:00 – 16:30'), findsOneWidget);
    expect(find.text('5 min arriving · 0 min leaving'), findsOneWidget);
    expect(find.text('Start: Up, every 15 min · Finish: No rounding'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Create group'));
    await tester.pump();
    await tester.pump();

    expect(fakes.groupManagement.calls, contains('create Van drivers 11,12'));
    final sent = fakes.groupManagement.created!;
    expect(sent.followEmployeeIds, [11], reason: 'Fabian uses the new hours');
    expect(sent.schedule!.breakMinutes, 30);
    expect((sent.schedule!.workHours.arrivalToleranceMinutes, sent.schedule!.workHours.startRounding?.intervalMinutes), (5, 15));
    expect([for (final d in sent.schedule!.workHours.days) (d.start, d.finish)], List.filled(5, ('08:00', '16:30')));
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Group Van drivers created.'), findsOneWidget);
    expect(find.text('5 groups'), findsOneWidget, reason: 'the new group is in the list');
    expect(fakes.groupManagement.calls.where((c) => c == 'overview'), hasLength(2), reason: 'the list reloads');
  });

  testWidgets('a duplicate name found at the save is shown under the name, on the first step', (tester) async {
    final fakes = _fakes();
    fakes.groupManagement.failNext =
        const ApiClientException.server(409, ApiError(code: ApiErrorCode.duplicateGroupName, message: 'x', field: 'name'));
    await _pump(tester, fakes, '/groups');

    await _tapPrimary(tester, 'Add group');
    await tester.enterText(_dialogField(0), 'Blue collar');
    await tester.pump();
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();
    await _tapPrimary(tester, 'Continue');
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();
    await _days(tester, ['Mon']);
    final times = tester.widgetList<ScheduleTimeField>(find.byType(ScheduleTimeField)).toList();
    times[0].onChanged!('08:00');
    times[1].onChanged!('16:30');
    tester.widgetList<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>)).last.onChanged!(30);
    await tester.pump();
    await _tapPrimary(tester, 'Continue');
    await _tapPrimary(tester, 'Continue');
    await _tapPrimary(tester, 'Create group');

    expect(find.text('Name'), findsOneWidget, reason: 'back on the first step');
    expect(find.text('A group with this name already exists.'), findsOneWidget);
  });

  testWidgets('the group page: Rename waits for a change; deactivating a group with employees says why not', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/2');

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('White collar still has employees'), findsOneWidget, reason: '1558:567');
    expect(find.text('Remove or move its 60 employees first, then deactivate the group.'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'OK'));
    await tester.pumpAndSettle();
    expect(fakes.groupManagement.calls, isNot(contains('deactivate 2')));

    await tester.tap(find.widgetWithText(JitanSecondaryButton, 'Rename'));
    await tester.pumpAndSettle();
    expect(_primary(tester, 'Save').onPressed, isNull, reason: 'nothing changed yet');
    await tester.enterText(_dialogField(0), 'White');
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Save'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(fakes.groupManagement.calls, contains('rename 2 White'));
    expect(find.text('Group renamed to White.'), findsOneWidget);
  });

  testWidgets('the group page: members with their companies; Remove asks; nobody only in it means no hours of its own', (tester) async {
    final fakes = _fakes();
    fakes.groupMembers.byGroup[3] = [member(11, 'Fabian', 'Peeters', 'FPT', groups: ['Drivers', 'White collar'])];
    await _pump(tester, fakes, '/groups/3');

    expect(find.text('Drivers'), findsWidgets);
    expect(find.text('Active · 1 employee in 1 company'), findsOneWidget);
    expect(find.text('Fabian Peeters'), findsOneWidget);
    expect(find.text('FPT'), findsOneWidget);
    expect(find.text('White collar'), findsWidgets, reason: 'the other group');
    expect(find.text('Every employee here is also in another group, so this group has no work hours of its own yet.'), findsOneWidget);

    // Remove shows while the row is hovered.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(find.text('Fabian Peeters')));
    await tester.pump();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Fabian Peeters from Drivers?'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(fakes.groupMembers.calls, contains('remove 3 11'));
    expect(find.text('Fabian Peeters removed from Drivers.'), findsOneWidget);
    expect(find.text('Add the employees who work these hours.'), findsOneWidget);
    expect(find.text('Set the days, hours and break the employees of this group work.'), findsOneWidget);
  });

  testWidgets('the group page opens the schedule wizard on the working hours, the group already known', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/2');

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Set work hours'));
    await tester.pump();
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();

    expect(find.text('Create schedule'), findsOneWidget, reason: 'a new schedule, not an edit');
    expect(find.text('Work days'), findsOneWidget, reason: 'the hours at once');
    expect(find.text('White collar'), findsWidgets, reason: 'the group under the title, not picked');
    expect(find.byType(JitanInlineSelect<int>), findsOneWidget, reason: 'only the break');
    expect(find.widgetWithText(JitanSecondaryButton, 'Cancel'), findsOneWidget, reason: 'no step to go back to');
  });

  testWidgets('a configured group shows its hours in the grouped card (1554:101)', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/1');

    expect(find.text('Work hours & break'), findsOneWidget);
    expect(find.text('Mon–Fri'), findsOneWidget);
    expect(find.text('08:00 – 16:30'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('5 min · 5 min'), findsOneWidget);
    expect(find.text('Up · Down, 15 min'), findsOneWidget);
    expect(find.text('Every employee in this group works these hours.'), findsOneWidget);
    expect(find.text('Monday'), findsNothing, reason: 'no day-by-day list');
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('the group page (1556:761): where each member works from; someone in two groups without hours is chosen here', (tester) async {
    final fakes = _fakes();
    fakes.groupMembers.byGroup[1] = [
      member(11, 'Fabian', 'Peeters', 'FPT', groups: ['Blue collar', 'White collar']),
      member(12, 'Kevin', 'De Vos', 'KDV', groups: ['Blue collar'], hoursFromGroupId: 1, hoursFromGroup: 'Blue collar'),
      member(13, 'Ann', 'Maes', 'AMS', groups: ['Blue collar', 'Drivers'], hoursFromGroupId: 3, hoursFromGroup: 'Drivers'),
    ];
    fakes.scheduleSource.groups = const [GroupSummary(id: 1, name: 'Blue collar'), GroupSummary(id: 2, name: 'White collar')];
    await _pump(tester, fakes, '/groups');

    // A row opens the group's page.
    await tester.tap(find.text('Blue collar').first);
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(find.text('Active · 3 employees in 1 company'), findsOneWidget);
    expect(find.text('This group'), findsOneWidget, reason: 'Kevin');
    expect(find.text('Needs a choice'), findsOneWidget, reason: 'Fabian');
    expect(
      find.text('Fabian Peeters has no work hours. They are also in another group; choose which group the hours come from.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Choose group →'));
    await tester.pumpAndSettle();
    expect(find.text('Where do Fabian Peeters’s hours come from?'), findsOneWidget);
    expect(find.text('Mon–Fri 08:00–16:30'), findsOneWidget, reason: 'Blue collar, with its hours');
    expect(fakes.scheduleSource.calls, ['get 7/11'], reason: 'in the company of the employee');
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Use these hours'));
    await tester.pump();
    await tester.pump();
    expect(fakes.scheduleSource.calls.last, 'set 7/11 1', reason: 'this group, suggested');
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Fabian Peeters now works the Blue collar hours.'), findsOneWidget);

    // Search narrows the employees.
    await tester.enterText(find.widgetWithText(TextField, 'Search employees'), 'kev');
    await tester.pump();
    expect(find.text('Fabian Peeters'), findsNothing);
    expect(find.text('Kevin De Vos'), findsOneWidget);
  });

  testWidgets('Schedules: a schedule’s Open group opens the group page, where its hours are managed', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/schedules');

    expect(find.text('Mon–Fri 08:00–16:30'), findsWidgets);
    await tester.tap(find.text('Blue collar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open group'));
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();

    expect(find.text('Work hours & break'), findsOneWidget, reason: 'the group page');
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('an empty group asks to confirm; an inactive group says so and offers Reactivate (1558:409)', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/3');

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Drivers?'), findsOneWidget);
    expect(find.text('The group can no longer be chosen. You can reactivate it later.'), findsOneWidget);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Deactivate'));
    await tester.pump();
    await tester.pump();
    expect(fakes.groupManagement.calls, contains('deactivate 3'));
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Drivers deactivated.'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/groups/4');
    await tester.pump();
    await tester.pump();
    fakes.schedules.succeedList([_blue, _white, _drivers]);
    await tester.pumpAndSettle();
    expect(find.text('Inactive · no employees'), findsOneWidget);
    expect(find.text('This group is inactive. Reactivate it to add employees or change its hours.'), findsOneWidget);
    expect(find.widgetWithText(JitanSecondaryButton, 'Add employees'), findsNothing);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Reactivate'));
    await tester.pump();
    await tester.pump();
    expect(fakes.groupManagement.calls, contains('reactivate 4'));
  });

  testWidgets('Create group: a click outside the dialog changes nothing', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');
    await _tapPrimary(tester, 'Add group');
    await tester.enterText(_dialogField(0), 'Drivers');
    await tester.pump();
    await tester.tap(find.text('Kevin De Vos · KDV'));
    await tester.pump();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Create group'), findsWidgets, reason: 'a click outside does not close the dialog');
    expect(find.text('1 chosen'), findsOneWidget, reason: 'nothing lost');
  });

  testWidgets('Create group where everyone keeps their hours: no work hours step', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');
    await _tapPrimary(tester, 'Add group');
    await tester.enterText(_dialogField(0), 'Testing');
    await tester.pump();
    await tester.tap(find.text('Fabian Peeters · FPT'));
    await tester.pump();
    expect(find.text('Hours: White collar'), findsOneWidget);
    expect(find.widgetWithText(JitanPrimaryButton, 'Continue'), findsNothing);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Create group'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Work days'), findsNothing, reason: 'the hours step is never shown');
    final sent = fakes.groupManagement.created!;
    expect((sent.name, sent.schedule), ('Testing', null));
    expect(sent.employeeIds, [11]);
    expect(sent.followEmployeeIds, isEmpty, reason: 'Fabian keeps White collar hours');
  });

  testWidgets('Create group with only a name: employees and hours left empty', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups');
    await _tapPrimary(tester, 'Add group');
    await tester.enterText(_dialogField(0), 'Cleaners');
    await tester.pump();
    expect(_primary(tester, 'Continue').onPressed, isNotNull, reason: 'employees are optional');
    await _tapPrimary(tester, 'Continue');
    fakes.schedules.succeedOptions();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set hours later'));
    await tester.pumpAndSettle();
    expect(find.text('Set later on the group page'), findsOneWidget, reason: 'the review, without attendance rules');
    expect(find.text('Rounding'), findsNothing);
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Create group'));
    await tester.pump();
    await tester.pump();

    final sent = fakes.groupManagement.created!;
    expect(sent.name, 'Cleaners');
    expect(sent.employeeIds, isEmpty);
    expect(sent.schedule, isNull);
  });

  testWidgets('Add employees on a group with hours (1555:162): "Hours: Blue collar" is sent for that employee', (tester) async {
    final fakes = _fakes();
    await _pump(tester, fakes, '/groups/1');

    await tester.tap(find.widgetWithText(JitanSecondaryButton, 'Add employees'));
    await tester.pumpAndSettle();
    expect(find.text('Hours: White collar'), findsNothing, reason: 'only on a ticked line');
    await tester.tap(find.text('Fabian Peeters · FPT'));
    await tester.pump();
    expect(find.text('Hours: White collar'), findsOneWidget, reason: 'Fabian is in White collar');
    await _hoursFrom(tester, 'Hours: Blue collar');
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add 1 employee'));
    await tester.pump();
    await tester.pump();

    expect(fakes.groupMembers.calls, contains('add 1 11 follow 11'));
  });
}
