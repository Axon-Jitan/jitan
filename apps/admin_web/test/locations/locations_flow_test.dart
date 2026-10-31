import 'package:admin_web/src/app/admin_app.dart';
import 'package:admin_web/src/locations/address_geocoder.dart';
import 'package:admin_web/src/locations/locations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../support/fake_locations.dart';
import '../support/test_services.dart';

Future<void> _pump(WidgetTester tester, TestServices fakes) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(TranslationScope(
    translations: Translations.english(),
    child: AdminApp(services: fakes.services, initialLocation: '/locations'),
  ));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(JitanFieldLabel, label),
  matching: find.byType(TextField),
);

JitanPrimaryButton _primary(WidgetTester tester, String label) =>
    tester.widget<JitanPrimaryButton>(find.widgetWithText(JitanPrimaryButton, label).last);

ApiClientException _apiError(int status, String code, {String? field}) =>
    ApiClientException.server(status, ApiError(code: code, message: 'refused', field: field));

void main() {
  testWidgets('the list: name, address, area, status and the count', (tester) async {
    final fakes = TestServices();
    fakes.locations.locations.addAll([location(1, 'Almeco office'), location(2, 'Old depot', active: false, radius: 75)]);
    await _pump(tester, fakes);

    expect(find.text('Locations'), findsWidgets);
    expect(find.text('Rue du Progrès 12, 7700 Mouscron'), findsNWidgets(2));
    expect(find.text('75 m'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('2 locations'), findsOneWidget);
  });

  testWidgets('search and status filter the list', (tester) async {
    final fakes = TestServices();
    fakes.locations.locations.addAll([location(1, 'Almeco office'), location(2, 'PCA workshop', street: 'Kortrijkstraat')]);
    await _pump(tester, fakes);

    await tester.enterText(find.byType(TextField).first, 'kortrijk');
    await tester.pumpAndSettle();
    expect(find.text('PCA workshop'), findsOneWidget);
    expect(find.text('Almeco office'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'nothing here');
    await tester.pumpAndSettle();
    expect(find.text('No locations match your search.'), findsOneWidget);
  });

  testWidgets('empty: one sentence and one action, no filters', (tester) async {
    await _pump(tester, TestServices());

    expect(find.text('Add your first location'), findsOneWidget);
    expect(find.byType(JitanSearchField), findsNothing);
    expect(find.widgetWithText(JitanPrimaryButton, 'Add location'), findsOneWidget);
  });

  testWidgets('a failed load says so and retries', (tester) async {
    final fakes = TestServices();
    fakes.locations.failList = _apiError(500, 'internal_error');
    await _pump(tester, fakes);
    expect(find.text('Unable to load locations. Try again →'), findsOneWidget);

    fakes.locations.failList = null;
    await tester.tap(find.text('Unable to load locations. Try again →'));
    await tester.pumpAndSettle();
    expect(find.text('Add your first location'), findsOneWidget);
  });

  testWidgets('add: the address finds the map, the pin can move, the server confirms', (tester) async {
    final fakes = TestServices();
    final geocoder = FakeGeocoder();
    fakes.locations.locations.add(location(1, 'PCA workshop'));
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: Scaffold(body: LocationsScreen(api: fakes.locations, maps: fakeLocationMaps(geocoder: geocoder))),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add location'));
    await tester.pumpAndSettle();
    expect(find.text('Click the map to place the pin'), findsOneWidget);
    expect(_primary(tester, 'Add location').onPressed, isNull, reason: 'nothing filled in');

    await tester.enterText(_field('Name'), 'Almeco office');
    await tester.enterText(_field('Street'), 'Rue du Progrès');
    await tester.enterText(_field('Number'), '12');
    await tester.enterText(_field('Postcode'), '7700');
    await tester.enterText(_field('City'), 'Mouscron');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(geocoder.searches, ['Rue du Progrès 12, 7700 Mouscron'], reason: 'once, after typing stops');
    expect(find.text('Drag the pin to the entrance'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fake-map')));
    await tester.pumpAndSettle();
    await tester.enterText(_field('City'), 'Moeskroen');
    await tester.pump(const Duration(seconds: 1));
    expect(geocoder.searches, hasLength(1), reason: 'HR placed the pin: the address no longer moves it');

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add location').last);
    await tester.pumpAndSettle();

    final sent = fakes.locations.lastRequest!;
    expect((sent.name, sent.number, sent.radiusMeters, sent.point.latitude), ('Almeco office', '12', 50, 50.75));
    expect(find.text('Almeco office added.'), findsOneWidget);
    expect(find.text('2 locations'), findsOneWidget);
  });

  testWidgets('a name in use is shown on the field and the dialog stays', (tester) async {
    final fakes = TestServices();
    fakes.locations.locations.add(location(1, 'Almeco office'));
    await _pump(tester, fakes);
    await tester.tap(find.text('Almeco office'));
    await tester.pumpAndSettle();

    fakes.locations.failNext = _apiError(409, ApiErrorCode.duplicateLocationName, field: 'name');
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('This name is already in use.'), findsOneWidget);
    expect(find.text('Edit location'), findsOneWidget);
  });

  testWidgets('edit: a row opens it, and saving reloads the list', (tester) async {
    final fakes = TestServices();
    fakes.locations.locations.add(location(1, 'Almeco office'));
    await _pump(tester, fakes);
    await tester.tap(find.text('Almeco office'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Name'), 'Almeco head office');
    await tester.pump();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(fakes.locations.calls, contains('update 1'));
    expect(find.text('Almeco head office saved.'), findsOneWidget);
    expect(find.text('Almeco head office'), findsOneWidget);
  });

  testWidgets('deactivate asks first; reactivate does not', (tester) async {
    final fakes = TestServices();
    fakes.locations.locations.add(location(1, 'Almeco office'));
    await _pump(tester, fakes);
    await tester.tap(find.text('Almeco office'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Almeco office?'), findsOneWidget);
    expect(fakes.locations.calls, isNot(contains('deactivate 1')));

    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Deactivate'));
    await tester.pumpAndSettle();
    expect(fakes.locations.calls, contains('deactivate 1'));
    expect(find.text('Inactive'), findsOneWidget);

    await tester.tap(find.text('Almeco office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reactivate'));
    await tester.pumpAndSettle();
    expect(fakes.locations.calls, contains('reactivate 1'));
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('with no map token a new location cannot be placed, and the page says why', (tester) async {
    final fakes = TestServices();
    fakes.locations.locations.add(location(1, 'PCA workshop'));
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TranslationScope(
      translations: Translations.english(),
      child: MaterialApp(
        theme: JitanTheme.web(),
        home: Scaffold(body: LocationsScreen(api: fakes.locations, maps: null)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(JitanPrimaryButton, 'Add location'));
    await tester.pumpAndSettle();

    expect(find.text('The map is not set up yet.'), findsOneWidget);
    await tester.enterText(_field('Name'), 'Depot');
    await tester.enterText(_field('Street'), 'Kaai');
    await tester.pump();
    expect(_primary(tester, 'Add location').onPressed, isNull);
  });

  group('AddressGeocoder', () {
    test('finds the first match', () async {
      late Uri asked;
      final geocoder = AddressGeocoder('pk.test', httpClient: MockClient((request) async {
        asked = request.url;
        return http.Response('{"features":[{"geometry":{"coordinates":[3.2167,50.7436]}}]}', 200);
      }));

      final point = await geocoder.find('Rue du Progrès 12, Mouscron');

      expect((point?.latitude, point?.longitude), (50.7436, 3.2167));
      expect(asked.queryParameters['q'], 'Rue du Progrès 12, Mouscron');
    });

    for (final (what, response) in [
      ('no match', http.Response('{"features":[]}', 200)),
      ('a refused token', http.Response('{}', 401)),
      ('an unexpected answer', http.Response('{"features":[{"geometry":{}}]}', 200)),
      ('not JSON', http.Response('oops', 200)),
    ]) {
      test('$what: nothing found, never an error', () async {
        final geocoder = AddressGeocoder('pk.test', httpClient: MockClient((_) async => response));

        expect(await geocoder.find('Nowhere'), isNull);
      });
    }
  });
}
