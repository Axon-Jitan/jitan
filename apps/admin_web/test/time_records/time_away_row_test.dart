import 'package:admin_web/src/time_records/time_record_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

TimeRecordDay _day(int away) => TimeRecordDay(
  employeeId: 1,
  employeeCode: 'EMU1',
  date: DateTime.utc(2026, 10, 22),
  status: TimeRecordStatus.complete,
  awayMinutes: away,
);

Future<void> _show(WidgetTester tester, int away) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TranslationScope(
    translations: Translations.english(),
    child: MaterialApp(
      theme: JitanTheme.web(),
      home: Scaffold(body: TimeRecordDialog(day: _day(away), mayCorrect: false)),
    ),
  ));
}

void main() {
  testWidgets('a day with time away shows how long, and what it means (D34)', (tester) async {
    await _show(tester, 125);

    expect(find.text('Time away'), findsOneWidget);
    expect(find.text('2h 05m'), findsOneWidget);
    expect(find.text('Not work time. Replaces the automatic break.'), findsOneWidget);
  });

  testWidgets('a day without time away shows no such row', (tester) async {
    await _show(tester, 0);

    expect(find.text('Time away'), findsNothing);
  });
}
