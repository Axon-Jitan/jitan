import 'package:admin_web/src/employees/employees_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jitan_api_client/jitan_api_client.dart';

import '../support/fake_employees_api.dart';

void main() {
  late FakeEmployeesApi api;
  late EmployeesController controller;

  setUp(() {
    api = FakeEmployeesApi();
    controller = EmployeesController(api, companyId: 7, searchDelay: const Duration(milliseconds: 10));
  });

  tearDown(() => controller.dispose());

  test('loads the employees of its company', () async {
    final load = controller.load();
    expect(controller.state, isA<EmployeesLoading>());

    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW')]);
    await load;

    expect((controller.state as EmployeesLoaded).employees.single.code, 'SBW');
    expect(api.calls, [(7, '')]);
  });

  test('exposes a failure', () async {
    final load = controller.load();
    api.fail(const ApiClientException.network('offline'));
    await load;

    expect(controller.state, isA<EmployeesFailed>());
  });

  test('searches with the trimmed text after the delay, always for its company', () async {
    controller.updateSearch('  sbw ');
    expect(api.calls, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(api.calls, [(7, 'sbw')]);
  });

  test('an outdated response never overwrites a newer one', () async {
    final slow = controller.load();
    controller.updateSearch('TVM');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    api.succeed([employee(2, 'Thomas', 'Vermeulen', 'TVM')], index: 1);
    api.succeed([employee(1, 'Disan', 'Ssebowa', 'SBW'), employee(2, 'Thomas', 'Vermeulen', 'TVM')], index: 0);
    await slow;
    await Future<void>.delayed(Duration.zero);

    final state = controller.state as EmployeesLoaded;
    expect(state.search, 'TVM');
    expect(state.employees.map((e) => e.code), ['TVM']);
  });
}
