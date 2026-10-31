import 'package:admin_web/src/auth/platform/session_store.dart';
import 'package:admin_web/src/dashboard/dashboard_period.dart';
import 'package:admin_web/src/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_dashboard.dart';

final _today = DateTime(2026, 10, 31, 9);

Future<void> _pump(WidgetTester tester, FakeDashboardApi api, {SessionStore? store}) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: Scaffold(
          body: DashboardScreen(api: api, store: store ?? MemorySessionStore(), today: () => _today),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('periods', () {
    (DateTime, DateTime) of(DashboardPreset preset) {
      final period = DashboardPeriod.of(preset, DateTime(2026, 3, 31, 15));
      return (period.from, period.to);
    }

    test('each shortcut, from a day at the end of a month', () {
      final today = DateTime(2026, 3, 31);
      expect(of(DashboardPreset.today), (today, today));
      expect(of(DashboardPreset.yesterday), (DateTime(2026, 3, 30), DateTime(2026, 3, 30)));
      expect(of(DashboardPreset.last7Days), (DateTime(2026, 3, 25), today));
      expect(of(DashboardPreset.last30Days), (DateTime(2026, 3, 2), today));
      expect(of(DashboardPreset.thisMonth), (DateTime(2026, 3), today));
      expect(of(DashboardPreset.lastMonth), (DateTime(2026, 2), DateTime(2026, 2, 28)));
      expect(of(DashboardPreset.thisYear), (DateTime(2026), today));
    });

    test('last month in January is December', () {
      final period = DashboardPeriod.of(DashboardPreset.lastMonth, DateTime(2026, 1, 15));

      expect((period.from, period.to), (DateTime(2025, 12), DateTime(2025, 12, 31)));
    });

    test('a shortcut comes back moved on; custom days stay', () {
      final later = DateTime(2026, 11, 2);

      expect(DashboardPeriod.decode('last7Days', later).to, later);
      final custom = DashboardPeriod(DashboardPreset.custom, DateTime(2026, 9, 1), DateTime(2026, 9, 5));
      final back = DashboardPeriod.decode(custom.encode(), later);
      expect((back.preset, back.from, back.to), (DashboardPreset.custom, custom.from, custom.to));
    });

    test('anything unusable falls back to the last 7 days', () {
      for (final value in [null, 'nonsense', 'custom', 'x:y', '2026-12-01:2026-12-02']) {
        expect(DashboardPeriod.decode(value, _today).preset, DashboardPreset.last7Days, reason: '$value');
      }
    });

    test('reversed, future and too long periods are not valid', () {
      DashboardPeriod p(DateTime from, DateTime to) => DashboardPeriod(DashboardPreset.custom, from, to);

      expect(p(DateTime(2026, 10, 2), DateTime(2026, 10, 1)).isValid(_today), isFalse);
      expect(p(DateTime(2026, 10, 2), DateTime(2026, 11, 1)).isValid(_today), isFalse);
      expect(p(DateTime(2025, 10, 30), DateTime(2026, 10, 31)).isValid(_today), isFalse);
      expect(p(DateTime(2025, 10, 31), DateTime(2026, 10, 31)).isValid(_today), isTrue);
    });
  });

  testWidgets('opens on the last 7 days with every card', (tester) async {
    final api = FakeDashboardApi();

    await _pump(tester, api);

    expect(api.calls, [(DateTime(2026, 10, 25), DateTime(2026, 10, 31))]);
    expect(find.text('Saturday 31 October'), findsOneWidget);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('25 – 31 Oct 2026'), findsOneWidget);
    expect(find.text('124'), findsOneWidget);
    expect(find.text('109 set up'), findsOneWidget);
    expect(find.text('3,127h'), findsOneWidget);
    expect(find.text('of 3,200h planned'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('91%'), findsOneWidget);
    expect(find.text('Corrections waiting for you'), findsOneWidget);
  });

  testWidgets('companies are largest first', (tester) async {
    final api = FakeDashboardApi()
      ..answer = dashboardWith(
        companies: const [
          DashboardCompany(id: 1, name: 'Small', employees: 2),
          DashboardCompany(id: 2, name: 'Large', employees: 40),
        ],
      );

    await _pump(tester, api);

    expect(tester.getTopLeft(find.text('Large')).dy, lessThan(tester.getTopLeft(find.text('Small')).dy));
  });

  testWidgets('a clear day says so, one calm line', (tester) async {
    final api = FakeDashboardApi()..answer = dashboardWith(toReview: 0, corrections: 0, employeesSetUp: 124);

    await _pump(tester, api);

    expect(find.text('Nothing needs attention'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('rows with nothing to do are left out', (tester) async {
    final api = FakeDashboardApi()..answer = dashboardWith(toReview: 0, employeesSetUp: 124);

    await _pump(tester, api);

    expect(find.text('Corrections waiting for you'), findsOneWidget);
    expect(find.text('Days to review'), findsNothing);
  });

  testWidgets('a period with nothing in it shows no percentage', (tester) async {
    final api = FakeDashboardApi()..answer = Dashboard.fromJson(dashboardWith(bars: 0).toJson()..addAll({'onTime': 0, 'late': 0, 'leftEarly': 0, 'toReview': 0}));

    await _pump(tester, api);

    expect(find.text('–'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failure offers a retry that loads again', (tester) async {
    final api = FakeDashboardApi()..fail = const ApiClientException.network('offline');

    await _pump(tester, api);

    api.fail = null;
    await tester.tap(find.text('The dashboard could not be loaded. Try again →'));
    await tester.pump();
    await tester.pump();

    expect(find.text('124'), findsOneWidget);
  });

  group('picker', () {
    testWidgets('nothing changes until Apply', (tester) async {
      final api = FakeDashboardApi();
      await _pump(tester, api);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last month'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(api.calls, hasLength(1));
      expect(find.text('25 – 31 Oct 2026'), findsOneWidget);
    });

    testWidgets('Apply loads the shortcut and this browser remembers it', (tester) async {
      final api = FakeDashboardApi();
      final store = MemorySessionStore();
      await _pump(tester, api, store: store);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last month'));
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(api.calls.last, (DateTime(2026, 9), DateTime(2026, 9, 30)));
      expect(find.text('1 – 30 Sep 2026'), findsOneWidget);
      expect(store.values.values, ['lastMonth']);
    });

    testWidgets('two clicks choose a custom period, in either order', (tester) async {
      final api = FakeDashboardApi();
      await _pump(tester, api);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20').last);
      await tester.pump();
      await tester.tap(find.text('12').last);
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(api.calls.last, (DateTime(2026, 10, 12), DateTime(2026, 10, 20)));
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('a future day cannot be clicked, nor a month after this one opened', (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      final api = FakeDashboardApi();
      await _pump(tester, api);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();

      final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(next.onPressed, isNull);
    });

    testWidgets('going back a month shows it', (tester) async {
      final api = FakeDashboardApi();
      await _pump(tester, api);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pump();

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('September 2026'), findsOneWidget);
    });

    testWidgets('a typed date that is not a date stops Apply', (tester) async {
      final api = FakeDashboardApi();
      await _pump(tester, api);

      await tester.tap(find.text('Last 7 days'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'someday');
      await tester.pump();

      expect(tester.widget<JitanPrimaryButton>(find.byType(JitanPrimaryButton)).onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '1 Oct 2026');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(api.calls.last, (DateTime(2026, 10, 1), DateTime(2026, 10, 31)));
    });
  });
}
