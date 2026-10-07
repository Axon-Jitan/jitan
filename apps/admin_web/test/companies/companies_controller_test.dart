import 'package:admin_web/src/companies/companies_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

import '../support/fake_companies_api.dart';

void main() {
  late FakeCompaniesApi api;
  late CompaniesController controller;

  setUp(() {
    api = FakeCompaniesApi();
    controller = CompaniesController(api, searchDelay: const Duration(milliseconds: 10));
  });

  tearDown(() => controller.dispose());

  test('starts loading, then shows the loaded companies', () async {
    final load = controller.load();
    expect(controller.state, isA<CompaniesLoading>());

    api.succeed([company(1, 'Almeco')]);
    await load;

    final state = controller.state as CompaniesLoaded;
    expect(state.companies.single.name, 'Almeco');
    expect(state.search, '');
    expect(api.calls, ['']);
  });

  test('exposes a failure without inventing data', () async {
    final load = controller.load();
    api.fail(const ApiClientException.network('offline'));
    await load;

    final state = controller.state as CompaniesFailed;
    expect(state.failure.kind, ApiFailureKind.network);
  });

  test('retry after a failure loads again', () async {
    final first = controller.load();
    api.fail(const ApiClientException.network('offline'));
    await first;

    final retry = controller.load();
    api.succeed([company(1, 'Almeco')]);
    await retry;

    expect(controller.state, isA<CompaniesLoaded>());
    expect(api.calls, ['', '']);
  });

  test('searches with the trimmed text after the delay', () async {
    controller.updateSearch('  Alm ');
    expect(api.calls, isEmpty, reason: 'waits for typing to pause');

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(api.calls, ['Alm']);
  });

  test('only the last of rapid keystrokes triggers a request', () async {
    controller
      ..updateSearch('A')
      ..updateSearch('Al')
      ..updateSearch('Alm');

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(api.calls, ['Alm']);
  });

  test('an outdated response never overwrites a newer one', () async {
    final slow = controller.load(); // request 0: unfiltered
    controller.updateSearch('PCA');
    await Future<void>.delayed(const Duration(milliseconds: 30)); // request 1: "PCA"

    api.succeed([company(2, 'PCA')], index: 1);
    api.succeed([company(1, 'Almeco'), company(2, 'PCA')], index: 0);
    await slow;
    await Future<void>.delayed(Duration.zero);

    final state = controller.state as CompaniesLoaded;
    expect(state.search, 'PCA');
    expect(state.companies.map((c) => c.name), ['PCA']);
  });

  test('a response after dispose is ignored', () async {
    final load = controller.load();
    controller.dispose();
    api.succeed(<CompanySummary>[]);
    await load;
    controller = CompaniesController(api); // so tearDown has something to dispose
  });
}
