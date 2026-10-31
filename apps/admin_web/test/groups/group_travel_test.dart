import 'package:admin_web/src/groups/group_travel_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_group_apis.dart';

Future<void> _pump(WidgetTester tester, FakeGroupManagementApi api, {bool enabled = true}) async {
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: Scaffold(body: GroupTravelRow(api: api, groupId: 4, enabled: enabled)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('saves at once', (tester) async {
    final api = FakeGroupManagementApi()..travelIsWork = false;
    await _pump(tester, api);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    expect(api.calls, ['travel 4 true']);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('an inactive group cannot change it', (tester) async {
    await _pump(tester, FakeGroupManagementApi()..travelIsWork = true, enabled: false);

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });

  testWidgets('without the proposed tables there is no switch', (tester) async {
    await _pump(tester, FakeGroupManagementApi());

    expect(find.text('Travel counts as work'), findsNothing);
  });
}
