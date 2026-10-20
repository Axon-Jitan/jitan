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

void main() {
  testWidgets('loading, then one row per group and kind with its summary', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Loading schedules…'), findsOneWidget);

    await _loaded(tester, api);

    for (final header in ['Group · Type', 'Days, hours & settings', 'Employee group', 'Actions']) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('Blue collar · Work hours'), findsOneWidget);
    expect(find.text('Blue collar · Break'), findsOneWidget);
    expect(find.text('Mon–Fri 08:00–16:30 · ±5 min · start Up · 15 min, finish Down · 15 min'), findsOneWidget);
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

  testWidgets('Add schedule: work hours for a group without any, saved by the server, then the list reloads', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    expect(find.text('Create schedule'), findsOneWidget);
    expect(find.text('Choose a group and at least one day to save.'), findsOneWidget);
    expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Save schedule')).onPressed, isNull);
    await _choose(tester, 'Employee group *', 'White collar');
    await tester.tap(find.text('Mon'));
    await tester.pump();
    expect(find.text('Applies from now. Records already registered keep their times.'), findsOneWidget);
    // The time menus hold 288 entries; pick through the field itself.
    _pickTime(tester, 'Start', '08:00');
    _pickTime(tester, 'Finish', '16:30');
    await tester.pump();

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

  testWidgets('a group that has work hours already: "Edit that schedule instead" fills them in', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

    await _choose(tester, 'Employee group *', 'Blue collar');
    expect(find.text('Blue collar already has work hours.'), findsOneWidget);
    expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Save schedule')).onPressed, isNull);

    await tester.tap(find.text('Edit that schedule instead →'));
    await tester.pumpAndSettle();
    expect(find.text('Edit schedule'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
  });

  testWidgets('"Mon–Fri" chooses the five weekdays', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);
    await _openAdd(tester, api);

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
    expect(tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, 'Save schedule')).onPressed, isNull);
  });

  testWidgets('Deactivate: confirmed, sent, and the list reloads', (tester) async {
    final api = await _pump(tester);
    await _loaded(tester, api);

    await tester.tap(find.byTooltip('Schedule actions').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate schedule?'), findsOneWidget);
    expect(find.text('Employees in Blue collar will no longer get these breaks.'), findsOneWidget);

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Deactivate'));
    await tester.pump();
    expect(api.writes.single.$1, 'removeBreaks');
    await _loaded(tester, api, [_white]);
    await tester.pumpAndSettle();

    expect(find.text('Deactivate schedule?'), findsNothing);
    expect(find.text('Schedule deactivated for Blue collar.'), findsOneWidget);
  });
}
