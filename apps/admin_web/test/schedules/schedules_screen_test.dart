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
final _differ = groupSchedule(
  4,
  'Apprentices',
  status: GroupScheduleStatus.employeesDiffer,
  variants: [
    ScheduleVariant(employeeCount: 2, workDays: workDays([1], '08:00', '16:00'), breaks: const []),
    ScheduleVariant(employeeCount: 1, workDays: workDays([1], '09:00', '17:00'), breaks: const []),
  ],
);

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

/// The schedule wizard on its own, for every group.
Future<void> _openAdd(WidgetTester tester, FakeSchedulesApi api) async {
  unawaited(showScheduleDialog(tester.element(find.byType(SchedulesScreen)), api: api, groups: [_blue, _white, _mixed]));
  await tester.pump();
  api.succeedOptions();
  await tester.pumpAndSettle();
}

/// Picks [group] from the Group line of the Hours card.
Future<void> _chooseGroup(WidgetTester tester, String group) async {
  await tester.tap(find.byType(JitanInlineSelect<int>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(group).last);
  await tester.pumpAndSettle();
}

/// The first time chip is Start, the second Finish.
void _pickTime(WidgetTester tester, int index, String time) =>
    tester.widget<ScheduleTimeField>(find.byType(ScheduleTimeField).at(index)).onChanged!(time);

Future<void> _tapDay(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip(name));
  await tester.pump();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Continue'));
  await tester.pumpAndSettle();
}

VoidCallback? _button(WidgetTester tester, String label) =>
    tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, label)).onPressed;

/// White collar, Monday 08:00–16:30 and a 30-minute break.
Future<void> _fillHours(WidgetTester tester) async {
  await _chooseGroup(tester, 'White collar');
  await _tapDay(tester, 'Mon');
  _pickTime(tester, 0, '08:00');
  _pickTime(tester, 1, '16:30');
  tester.widgetList<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>)).last.onChanged!(30);
  await tester.pump();
}

void main() {
  testWidgets('loading, then one row per group (1547:2): days and hours, break, status; a count in the header', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Loading schedules…'), findsOneWidget);

    await _loaded(tester, api, [_blue, _white, _mixed, _differ]);

    for (final header in ['Group', 'Days & hours', 'Break', 'Status']) {
      expect(find.text(header), findsWidgets, reason: header);
    }
    expect(find.text('Rounding'), findsNothing, reason: 'in the pop-up, not the table');
    expect(find.text('Mon–Fri 08:00–16:30'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('2 groups'), findsOneWidget, reason: 'White collar and Mixed have none, no row');
    expect(find.text('Different hours'), findsWidgets);
  });

  testWidgets('nothing yet: a calm page with Add schedule (1548:618)', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api, [_white]);

    expect(find.text('No schedules yet'), findsOneWidget);
    expect(find.text('Give an employee group its work days, hours and break.'), findsOneWidget);
    expect(find.widgetWithText(JitanPrimaryButton, 'Add schedule'), findsOneWidget, reason: 'one button, not two');
    expect(find.byType(JitanPillSwitch<Object?>), findsNothing);
  });

  testWidgets('error with retry; then a search or a status that shows nothing says so', (tester) async {
    final api = await _pump(tester);
    api.failList(const ApiClientException.network('offline'));
    await tester.pump();

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(api.listCalls, 2);
    await _loaded(tester, api);

    await tester.tap(find.text('Different hours'));
    await tester.pump();
    expect(find.text('No groups with different hours'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField).first, 'nobody');
    await tester.pump();
    expect(find.text('No matching groups'), findsOneWidget);
    expect(find.text('Try another name.'), findsOneWidget);
  });

  testWidgets('Add schedule: Hours, Rules, Review; one save, then a toast and the list reloads', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await tester.tap(find.text('Add schedule'));
    await tester.pump();
    api.succeedOptions();
    await tester.pumpAndSettle();

    expect(find.text('Create schedule'), findsOneWidget);
    for (final step in ['Hours', 'Rules', 'Review']) {
      expect(find.text(step), findsWidgets, reason: step);
    }
    expect(_button(tester, 'Continue'), isNull, reason: 'no group yet');
    await _fillHours(tester);
    expect(find.byType(ScheduleTimeField), findsNWidgets(2), reason: 'start and finish; no break time');
    await _continue(tester);

    expect(find.text('Arrival tolerance'), findsOneWidget);
    await _continue(tester);
    expect(find.text('Mon'), findsOneWidget, reason: 'the work days');
    expect(find.text('08:00 – 16:30'), findsOneWidget);
    expect(find.text('Start up, finish down · 15 min'), findsNothing, reason: 'a new schedule has no rounding yet');
    expect(find.text('Applies from now to the 3 employees of White collar. Records already registered keep their times.'), findsOneWidget);

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

  testWidgets('the explanations are behind an ⓘ on each line', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    List<String> infos() => [for (final i in tester.widgetList<JitanInfoIcon>(find.byType(JitanInfoIcon))) i.message];

    expect(infos(), hasLength(4), reason: 'group, work days, hours, break');
    expect(infos().first, contains('Example: Blue collar'));
    expect(infos().last, contains('30 min on 08:00–16:30 is 12:00–12:30'));
    await _fillHours(tester);
    await _continue(tester);
    expect(infos(), hasLength(4), reason: 'arrival, leaving, start rounding, finish rounding');
    expect(infos().first, contains('08:04 is on time, 08:06 is late'));
  });

  testWidgets('times are typed in and tidied: "730" becomes "07:30"', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _chooseGroup(tester, 'White collar');

    final start = find.descendant(of: find.byType(ScheduleTimeField).first, matching: find.byType(TextField));
    await tester.enterText(start, '730');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.tap(find.text('Work days'));
    await tester.pump();

    expect(find.text('07:30'), findsOneWidget);
  });

  testWidgets('Back keeps what was entered; finish before start stays on Hours', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _chooseGroup(tester, 'White collar');
    await _tapDay(tester, 'Mon');
    _pickTime(tester, 0, '16:00');
    _pickTime(tester, 1, '08:00');
    tester.widgetList<JitanInlineSelect<int>>(find.byType(JitanInlineSelect<int>)).last.onChanged!(30);
    await tester.pump();
    await _continue(tester);
    expect(find.text('Finish must be after start.'), findsOneWidget);

    _pickTime(tester, 1, '17:00');
    await tester.pump();
    await _continue(tester);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(tester.widget<ScheduleTimeField>(find.byType(ScheduleTimeField).first).value, '16:00');
  });

  testWidgets('"Set hours per day": a line per chosen day with its own times; and back', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _chooseGroup(tester, 'White collar');
    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
      await _tapDay(tester, day);
    }
    _pickTime(tester, 0, '07:30');
    _pickTime(tester, 1, '16:00');
    await tester.pump();

    await tester.tap(find.text('Set hours per day'));
    await tester.pumpAndSettle();
    for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']) {
      expect(find.text(day), findsOneWidget, reason: day);
    }
    expect(find.byType(ScheduleTimeField), findsNWidgets(10), reason: 'start and finish for five days');
    expect(tester.widget<ScheduleTimeField>(find.byType(ScheduleTimeField).at(9)).value, '16:00', reason: 'starts from the shared hours');

    await tester.tap(find.text('Use the same hours every day'));
    await tester.pumpAndSettle();
    expect(find.byType(ScheduleTimeField), findsNWidgets(2));
  });

  testWidgets('a group that has a schedule: "Edit that schedule instead" fills it in', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    await _chooseGroup(tester, 'Blue collar');
    expect(find.text('Blue collar already has a schedule.'), findsOneWidget);
    expect(_button(tester, 'Continue'), isNull);

    await tester.tap(find.text('Edit that schedule instead →'));
    await tester.pumpAndSettle();
    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
  });

  testWidgets('round day buttons: chosen days are dark', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _chooseGroup(tester, 'White collar');

    await _tapDay(tester, 'Mon');
    await _tapDay(tester, 'Wed');

    final chosen = [
      for (final dot in tester.widgetList<ScheduleDayDot>(find.byType(ScheduleDayDot))) if (dot.selected) dot.name,
    ];
    expect(chosen, ['Mon', 'Wed']);
    expect([for (final dot in tester.widgetList<ScheduleDayDot>(find.byType(ScheduleDayDot))) dot.letter], [
      'M', 'T', 'W', 'T', 'F', 'S', 'S', //
    ]);
  });

  testWidgets('a group nobody is only in is blocked', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    await _chooseGroup(tester, 'Mixed');

    expect(find.text('Add an employee who is only in Mixed first.'), findsOneWidget);
    expect(_button(tester, 'Continue'), isNull);
  });

  testWidgets('a row opens its pop-up (1552:386); Remove break asks, sends, and a toast follows', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);

    await tester.tap(find.text('Blue collar'));
    await tester.pumpAndSettle();
    expect(find.text('Active · 3 employees'), findsOneWidget);
    for (final text in ['Mon–Fri', '08:00 – 16:30', '30 min', '5 min arriving · 5 min leaving', 'Start up, finish down · 15 min']) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Open group'), findsOneWidget);
    expect(find.text('Remove hours'), findsOneWidget);
    await tester.tap(find.text('Remove break'));
    await tester.pumpAndSettle();
    expect(find.text('Remove the break of Blue collar?'), findsOneWidget);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Remove break'));
    await tester.pump();
    expect(api.writes.single.$1, 'removeBreaks');
    await _loaded(tester, api, [_white]);
    await tester.pumpAndSettle();

    expect(find.text('Remove the break of Blue collar?'), findsNothing);
    expect(find.text('Break removed from Blue collar.'), findsOneWidget);
  });

  testWidgets('a group whose employees differ says so in its pop-up', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api, [_differ]);

    await tester.tap(find.text('Apprentices'));
    await tester.pumpAndSettle();
    expect(find.text('Different hours · 3 employees'), findsOneWidget);
    expect(find.text('The employees of this group have different hours. Edit gives all of them the same schedule.'), findsOneWidget);
  });

  testWidgets('the pop-up → Edit opens the wizard filled in, the group under the title', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);

    await tester.tap(find.text('Blue collar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Edit'));
    await tester.pump();
    api.succeedOptions();
    await tester.pumpAndSettle();

    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('Blue collar'), findsWidgets);
    expect(find.byType(JitanInlineSelect<int>), findsOneWidget, reason: 'only the break; the group is fixed');
    expect(find.text('08:00'), findsOneWidget);
  });
}
