import 'package:admin_web/src/schedules/schedule_form_fields.dart';
import 'package:admin_web/src/schedules/schedule_rows.dart';
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

Future<void> _openAdd(WidgetTester tester, FakeSchedulesApi api) async {
  await tester.tap(find.text('Add schedule'));
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

void main() {
  testWidgets('loading, then one row per group and kind with its days and hours', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Loading schedules…'), findsOneWidget);

    await _loaded(tester, api);

    expect(find.text('Group schedules'), findsOneWidget);
    for (final header in ['Group · Type', 'Days & hours', 'Actions']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Blue collar · Work hours'), findsOneWidget);
    expect(find.text('Blue collar · Break'), findsOneWidget);
    expect(find.text('Mon–Fri 08:00–16:30'), findsOneWidget);
    expect(find.text('Mon–Fri · 12:00 · 30 min'), findsOneWidget);
    expect(find.textContaining('White collar ·'), findsNothing, reason: 'no schedule, no row');
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

  testWidgets('Add schedule, 3 steps: group & type, working hours, attendance rules; saved, then the list reloads', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    // Step 1
    expect(find.text('Create schedule'), findsOneWidget);
    expect(find.text('1 Group & type'), findsOneWidget);
    expect(find.text('Applies to all employees in this group.'), findsOneWidget);
    expect(_button(tester, 'Continue'), isNull, reason: 'no group yet');
    await _choose(tester, 'Employee group *', 'White collar');
    await _continue(tester);

    // Step 2
    expect(_button(tester, 'Continue'), isNull, reason: 'no day yet');
    await tester.tap(find.text('Mon'));
    await tester.pump();
    // The time menus hold 288 entries; pick through the field itself.
    _pickTime(tester, 'Start', '08:00');
    _pickTime(tester, 'Finish', '16:30');
    await tester.pump();
    await _continue(tester);

    // Step 3
    expect(find.text('Actual registrations remain unchanged; tolerance affects attendance status.'), findsOneWidget);
    api.writeResult = groupSchedule(2, 'White collar', work: workDays([1], '08:00', '16:30'));
    await tester.tap(find.text('Save schedule'));
    await tester.pump();
    await tester.pump();
    await _loaded(tester, api, [_blue, api.writeResult!, _mixed]);
    await tester.pumpAndSettle();

    final (method, groupId, request as SetWorkHoursRequest) = api.writes.single;
    expect((method, groupId), ('setWorkHours', 2));
    expect([for (final d in request.days) (d.dayId, d.start, d.finish)], [(11, '08:00', '16:30')]);
    expect(find.text('Create schedule'), findsNothing);
    expect(find.text('Schedule saved for White collar.'), findsOneWidget);
    expect(api.listCalls, 2, reason: 'reloaded after the save');
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
    expect(find.text('2 Working hours'), findsOneWidget);

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
    expect(find.text('Only selected working days have time fields. Unselected days are excluded.'), findsOneWidget);
  });

  testWidgets('a break: details, then a review of what will be saved', (tester) async {
    final api = await _pump(tester);
    // A group with work hours and no break yet.
    await _loaded(tester, api, [groupSchedule(4, 'Green', work: workDays([1, 2, 3, 4, 5], '08:00', '16:30'))]);
    await _openAdd(tester, api);
    await _choose(tester, 'Employee group *', 'Green');
    await tester.tap(find.widgetWithText(JitanSelectField<ScheduleKind>, 'Schedule type *'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Break').last);
    await tester.pumpAndSettle();
    expect(find.text('2 Break details'), findsOneWidget);
    await _continue(tester);

    await tester.tap(find.text('Mon–Fri'));
    await tester.pump();
    tester.widget<ScheduleTimeField>(find.byType(ScheduleTimeField)).onChanged!('12:00');
    tester.widget<JitanSelectField<int>>(find.widgetWithText(JitanSelectField<int>, 'Length')).onChanged!(30);
    await tester.pump();
    await _continue(tester);

    expect(find.text('Review break'), findsOneWidget);
    expect(find.text('Green · Mon–Fri · 12:00 · 30 minutes'), findsOneWidget);
  });

  testWidgets('a group that has work hours already: "Edit that schedule instead" fills them in', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    await _choose(tester, 'Employee group *', 'Blue collar');
    expect(find.text('Blue collar already has work hours.'), findsOneWidget);
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

  testWidgets('a break for a group without work hours is stopped on step 1', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    await _choose(tester, 'Employee group *', 'White collar');
    await tester.tap(find.widgetWithText(JitanSelectField<ScheduleKind>, 'Schedule type *'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Break').last);
    await tester.pumpAndSettle();

    expect(find.text('Set the work hours of White collar before its breaks.'), findsOneWidget);
    expect(_button(tester, 'Continue'), isNull);
  });

  testWidgets('the wizard keeps the same size on every step', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);
    Size size() => tester.getSize(find.byType(Dialog));

    final first = size();
    await _choose(tester, 'Employee group *', 'White collar');
    await _continue(tester);
    expect(size(), first, reason: 'step 2');

    await tester.tap(find.text('Mon–Fri'));
    await tester.pump();
    await tester.tap(find.text('Same hours every working day'));
    await tester.pumpAndSettle();
    expect(size(), first, reason: 'step 2 with five days of hours');
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

    await tester.tap(find.byTooltip('Schedule actions').at(1));
    await tester.pumpAndSettle();
    expect(find.text('Manage schedules'), findsOneWidget);
    expect(find.text('Blue collar · Break'), findsNWidgets(2), reason: 'the row and the dialog subtitle');
    await tester.tap(find.text('Remove schedule'));
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
    expect(find.text('1 Group & type'), findsOneWidget);
  });
}
