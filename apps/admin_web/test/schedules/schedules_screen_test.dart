import 'dart:async';

import 'package:admin_web/src/schedules/schedule_dialog.dart';
import 'package:admin_web/src/schedules/schedule_form_fields.dart';
import 'package:admin_web/src/schedules/schedules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_schedules_api.dart';

final _blue = groupSchedule(
  1,
  'Blue collar',
  work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'),
  breakDays: breaks([1, 2, 3, 4, 5], '12:00', 30),
);
final _white = groupSchedule(2, 'White collar', status: GroupScheduleStatus.noSchedule);
final _mixed = groupSchedule(3, 'Mixed', status: GroupScheduleStatus.noSingleGroupEmployees);

Future<FakeSchedulesApi> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeSchedulesApi();
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.light(),
        home: Scaffold(body: SchedulesScreen(api: api)),
      ),
    ),
  );
  return api;
}

Future<void> _loaded(WidgetTester tester, FakeSchedulesApi api, [List<GroupSchedule>? groups]) async {
  api.succeedList(groups ?? [_blue, _white, _mixed]);
  await tester.pump();
}

/// The schedule wizard on its own (the page has no "Add schedule" any more;
/// the wizard opens from "···" Edit and from a group's page).
Future<void> _openAdd(WidgetTester tester, FakeSchedulesApi api) async {
  unawaited(showScheduleDialog(tester.element(find.byType(SchedulesScreen)), api: api, groups: [_blue, _white, _mixed]));
  await tester.pump();
  api.succeedOptions();
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String field, String option) async {
  await tester.tap(find.widgetWithText(JitanSelectField<int>, field).first, warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

/// Start is the first time field of the hours table, Finish the second.
void _pickTime(WidgetTester tester, String label, String time) => tester
    .widget<ScheduleTimeField>(find.byType(ScheduleTimeField).at(label == 'Start' ? 0 : 1))
    .onChanged!(time);

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
  await tester.pumpAndSettle();
}

VoidCallback? _button(WidgetTester tester, String label) =>
    tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, label)).onPressed;

/// Step 1 for White collar, then step 2: Monday 08:00–16:30 and a 30-minute break.
Future<void> _fillHours(WidgetTester tester) async {
  await _choose(tester, 'Employee group *', 'White collar');
  await _continue(tester);
  await tester.tap(find.text('Mon'));
  await tester.pump();
  _pickTime(tester, 'Start', '08:00');
  _pickTime(tester, 'Finish', '16:30');
  tester.widget<JitanSelectField<int>>(find.widgetWithText(JitanSelectField<int>, 'Length')).onChanged!(30);
  await tester.pump();
}

void main() {
  testWidgets('loading, then one row per group (1458:2): days and hours, break, rounding', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Loading schedules…'), findsOneWidget);

    await _loaded(tester, api);

    for (final header in ['Group', 'Days & hours', 'Break', 'Rounding', 'Status']) {
      expect(find.text(header), findsWidgets, reason: header);
    }
    expect(find.text('Blue collar'), findsWidgets);
    expect(find.text('Mon–Fri 08:00–16:30'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('1 group with a schedule'), findsOneWidget, reason: 'White collar has none, no row');
  });

  testWidgets('empty state when no group has a schedule', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api, [_white]);

    expect(find.text('No schedules yet'), findsOneWidget);
  });

  testWidgets('error state with retry, then a search that matches nothing', (tester) async {
    final api = await _pump(tester);
    api.failList(const ApiClientException.network('offline'));
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(api.listCalls, 2);
    await _loaded(tester, api);

    await tester.enterText(find.byType(TextField).first, 'nobody');
    await tester.pump();
    expect(find.text('No matching schedules'), findsOneWidget);
  });

  testWidgets('Add schedule: group, hours & break, attendance, review; one save, then the list reloads', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await tester.tap(find.text('Add schedule'));
    await tester.pump();
    api.succeedOptions();
    await tester.pumpAndSettle();

    expect(find.text('Create schedule'), findsOneWidget);
    for (final step in ['1 Group', '2 Working hours & break', '3 Attendance rules', '4 Review']) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    expect(_button(tester, 'Continue'), isNull, reason: 'no group yet');
    await _fillHours(tester);

    // Step 2 holds the break too: always part of the schedule, length only.
    expect(find.text('Every working day. Deducted automatically; employees do not register breaks.'), findsOneWidget);
    expect(find.byType(ScheduleTimeField), findsNWidgets(2), reason: 'start and finish; no break time');
    await _continue(tester);

    // Step 3, then the review.
    expect(find.text('Actual registrations remain unchanged; the registered time is rounded with these rules.'), findsOneWidget);
    await _continue(tester);
    expect(find.text('Review schedule'), findsOneWidget);
    expect(find.text('Mon 08:00–16:30'), findsOneWidget);
    expect(find.text('30 min every working day'), findsOneWidget);

    api.writeResult = groupSchedule(2, 'White collar', work: workDays([1], '08:00', '16:30'), breakDays: breaks([1], '12:00', 30));
    await tester.tap(find.text('Save schedule'));
    await tester.pump();
    await tester.pump();
    await _loaded(tester, api, [_blue, api.writeResult!, _mixed]);
    await tester.pumpAndSettle();

    final (method, groupId, request as SetGroupScheduleRequest) = api.writes.single;
    expect((method, groupId), ('setSchedule', 2));
    expect([for (final d in request.workHours.days) (d.dayId, d.start, d.finish)], [(11, '08:00', '16:30')]);
    expect(request.breakMinutes, 30);
    expect(find.text('Create schedule'), findsNothing);
    expect(find.text('Schedule saved for White collar.'), findsOneWidget);
  });

  testWidgets('every field has an ⓘ that explains it with an example', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    List<String> infos() => [for (final i in tester.widgetList<JitanInfoIcon>(find.byType(JitanInfoIcon))) i.message];

    expect(infos(), [contains('Example: Blue collar')]);
    await _fillHours(tester);
    expect(infos(), hasLength(4), reason: 'working days, start, finish, break length');
    expect(infos().last, contains('30 min on 08:00–16:30 is 12:00–12:30'));
    await _continue(tester);
    expect(infos(), hasLength(4), reason: 'arrival, leaving, start rounding, finish rounding');
    expect(infos().first, contains('08:04 is on time, 08:06 is late'));
  });

  testWidgets('times are typed in and tidied: "730" becomes "07:30"', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _choose(tester, 'Employee group *', 'White collar');
    await _continue(tester);

    final start = find.descendant(of: find.byType(ScheduleTimeField).first, matching: find.byType(TextField));
    await tester.enterText(start, '730');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Working days'));
    await tester.pump();

    expect(find.text('07:30'), findsOneWidget);
    expect(find.byType(MenuItemButton), findsNothing, reason: 'no time drop-down');
  });

  testWidgets('Back keeps what was entered; finish before start stops at step 2', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _choose(tester, 'Employee group *', 'White collar');
    await _continue(tester);

    await tester.tap(find.text('Mon'));
    await tester.pump();
    _pickTime(tester, 'Start', '16:00');
    _pickTime(tester, 'Finish', '08:00');
    await tester.pump();
    await _continue(tester);
    expect(find.text('Finish must be after start.'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Applies to all employees in this group.'), findsOneWidget);
    await _continue(tester);
    expect(tester.widget<ScheduleTimeField>(find.byType(ScheduleTimeField).first).value, '16:00');
  });

  testWidgets('hours per day: a table with Day, Start and Finish', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _choose(tester, 'Employee group *', 'White collar');
    await _continue(tester);

    await tester.tap(find.text('Mon–Fri'));
    await tester.pump();
    await tester.tap(find.text('Same hours every working day'));
    await tester.pumpAndSettle();

    expect(find.text('Day'), findsOneWidget);
    expect(find.byType(ScheduleTimeField), findsNWidgets(10), reason: 'start and finish for five days');
  });

  testWidgets('the wizard keeps the same size on every step', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    Size size() => tester.getSize(find.byType(Dialog));

    final first = size();
    await _fillHours(tester);
    expect(size(), first, reason: 'hours & break step');
    await tester.tap(find.text('Same hours every working day'));
    await tester.pumpAndSettle();
    expect(size(), first, reason: 'hours per day');
    await _continue(tester);
    expect(size(), first, reason: 'attendance step');
  });

  testWidgets('a group that has a schedule: "Edit that schedule instead" fills it in', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    await _choose(tester, 'Employee group *', 'Blue collar');
    expect(find.text('Blue collar already has a schedule.'), findsOneWidget);
    expect(_button(tester, 'Continue'), isNull);

    await tester.tap(find.text('Edit that schedule instead →'));
    await tester.pumpAndSettle();
    expect(find.text('Edit schedule'), findsOneWidget);
    await _continue(tester);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
  });

  testWidgets('"Mon–Fri" chooses the five weekdays', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _choose(tester, 'Employee group *', 'White collar');
    await _continue(tester);

    await tester.tap(find.text('Mon–Fri'));
    await tester.pump();

    final chosen = [
      for (final toggle in tester.widgetList<ScheduleDayToggle>(find.byType(ScheduleDayToggle)))
        if (toggle.selected) toggle.label,
    ];
    expect(chosen, ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']);
  });

  testWidgets('a group nobody is only in is blocked', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    await _choose(tester, 'Employee group *', 'Mixed');

    expect(find.text('Add an employee who is only in Mixed first.'), findsOneWidget);
    expect(_button(tester, 'Continue'), isNull);
  });

  testWidgets('"···" opens Manage schedules; Remove asks, sends, and the list reloads', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);

    await tester.tap(find.byTooltip('Schedule actions').first);
    await tester.pumpAndSettle();
    expect(find.text('Manage schedules'), findsOneWidget);
    expect(find.text('Open group'), findsOneWidget);
    expect(find.text('Remove work hours'), findsOneWidget);
    await tester.tap(find.text('Remove break'));
    await tester.pumpAndSettle();
    expect(find.text('Remove schedule?'), findsOneWidget);
    expect(find.text('Employees in Blue collar will no longer get these breaks.'), findsOneWidget);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove'));
    await tester.pump();
    expect(api.writes.single.$1, 'removeBreaks');
    await _loaded(tester, api, [_white]);
    await tester.pumpAndSettle();

    expect(find.text('Remove schedule?'), findsNothing);
    expect(find.text('Schedule removed from Blue collar.'), findsOneWidget);
  });

  testWidgets('Manage schedules → Edit schedule opens the wizard filled in', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);

    await tester.tap(find.byTooltip('Schedule actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit schedule'));
    await tester.pump();
    api.succeedOptions();
    await tester.pumpAndSettle();

    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('1 Group'), findsOneWidget);
  });
}
