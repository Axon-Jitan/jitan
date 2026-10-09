import 'package:jitan_api/src/http/api_exception.dart';
import 'package:jitan_api/src/http/path_id.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

/// Matches `[0-9]+` but does not fit in an int.
const _huge = '99999999999999999999999';

void main() {
  test('pathId parses an id and turns one too large for an int into 404', () {
    expect(pathId('42', 'No such employee.'), 42);
    expect(
      () => pathId(_huge, 'No such employee.'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404).having((e) => e.message, 'message', 'No such employee.')),
    );
  });

  group('an id too large for an int is 404 on every route, never 500', () {
    const employee = '/companies/1/employees/$_huge';
    const company = '/companies/$_huge/employees/2';
    const assignments = '/companies/1/employees/2/assignments';
    final requests = <String, Future<dynamic> Function(TestApp app)>{
      'GET employee details': (app) => app.get(employee),
      'GET employees of a company': (app) => app.get('/companies/$_huge/employees'),
      'POST onboarding QR': (app) => app.post('$employee/onboarding-qr', '{}'),
      'GET assignments (company id)': (app) => app.get('$company/assignments/companies'),
      'GET assignments (employee id)': (app) => app.get('$employee/assignments/groups'),
      'POST assignments': (app) => app.post('$employee/assignments/companies', '{"ids": [1]}'),
      'PUT language': (app) => app.put('$employee/assignments/language', '{"languageId": 1}'),
      'GET credential groups': (app) => app.get('$employee/assignments/credential-groups'),
      'POST credential groups': (app) => app.post('$employee/assignments/credential-groups', '{"ids": [1]}'),
      'DELETE company (target id)': (app) => app.delete('$assignments/companies/$_huge'),
      'DELETE group (target id)': (app) => app.delete('$assignments/groups/$_huge'),
      'GET time registrations': (app) => app.get('$employee/time-registrations?from=2026-10-01&to=2026-10-08'),
    };

    for (final MapEntry(key: name, value: send) in requests.entries) {
      test(name, () async {
        final app = TestApp(devUserId: 9, activeUserIds: {9});
        app.companies.existingIds = {1};
        app.employees.members = {(1, 2)};

        final response = await send(app);

        expect(response.statusCode, 404);
      });
    }
  });
}
