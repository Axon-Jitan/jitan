import 'package:jitan_api/src/auth/permission.dart';
import 'package:jitan_api/src/database/database_exception.dart';
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  group('GET /companies', () {
    test('returns the company list for the acting user', () async {
      final app = TestApp(devUserId: 7, activeUserIds: {7});
      app.companies.companies = [
        company(1, 'Almeco', employees: 48),
        company(2, 'PCA', active: false, employees: 36),
      ];

      final response = await app.get('/companies');
      final body = await jsonBody(response);

      expect(response.statusCode, 200);
      expect(body, {
        'companies': [
          {'id': 1, 'name': 'Almeco', 'isActive': true, 'employeeCount': 48, 'lastUpdatedAt': null},
          {'id': 2, 'name': 'PCA', 'isActive': false, 'employeeCount': 36, 'lastUpdatedAt': null},
        ],
      });
      expect(app.permissions.checked, [(7, Permission.viewCompanies)]);
    });

    test('returns an empty list when there are no companies', () async {
      final app = TestApp();

      final body = await jsonBody(await app.get('/companies'));

      expect(body, {'companies': <Object?>[]});
    });

    test('passes the trimmed search text to the repository', () async {
      final app = TestApp();

      await app.get('/companies?search=%20Alm%20');

      expect(app.companies.searches, ['Alm']);
    });

    test('treats a blank search as no filter', () async {
      final app = TestApp();

      await app.get('/companies?search=%20%20');

      expect(app.companies.searches, [null]);
    });

    test('rejects an over-long search with 400', () async {
      final app = TestApp();

      final response = await app.get('/companies?search=${'a' * 101}');

      expect(response.statusCode, 400);
      expect((await jsonBody(response))['error'], containsPair('code', 'bad_request'));
      expect(app.companies.searches, isEmpty);
    });

    test('answers 401 when no authentication mechanism is configured', () async {
      final app = TestApp(devUserId: null);

      final response = await app.get('/companies');

      expect(response.statusCode, 401);
      expect((await jsonBody(response))['error'], containsPair('code', 'unauthenticated'));
    });

    test('answers 401 when the dev user is not an active user', () async {
      final app = TestApp(devUserId: 99, activeUserIds: {1});

      final response = await app.get('/companies');

      expect(response.statusCode, 401);
      expect(app.companies.searches, isEmpty);
    });

    test('answers 403 when the permission evaluator denies access', () async {
      final app = TestApp(allowPermissions: false);

      final response = await app.get('/companies');

      expect(response.statusCode, 403);
      expect((await jsonBody(response))['error'], containsPair('code', 'forbidden'));
      expect(app.companies.searches, isEmpty);
    });

    test('answers 503 when the database is unavailable', () async {
      final app = TestApp();
      app.companies.failWith = const DatabaseUnavailableException('down');

      final response = await app.get('/companies');

      expect(response.statusCode, 503);
    });

    test('answers a generic 500 for a query error, hiding the SQL detail', () async {
      final app = TestApp();
      app.companies.failWith = const DatabaseQueryException("Unknown column 'companyNme'", errorCode: 1054);

      final response = await app.get('/companies');
      final body = await response.readAsString();

      expect(response.statusCode, 500);
      expect(body, isNot(contains('companyNme')));
      expect(body, contains('internal_error'));
    });
  });

  test('unknown endpoints answer a structured 404', () async {
    final app = TestApp();

    final response = await app.get('/nope');

    expect(response.statusCode, 404);
    expect((await jsonBody(response))['error'], containsPair('code', 'not_found'));
  });
}
