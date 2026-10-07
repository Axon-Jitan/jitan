import 'package:jitan_api/src/database/database_exception.dart';
import 'package:test/test.dart';

import '../support/test_app.dart';

void main() {
  test('GET /health answers without authentication', () async {
    final app = TestApp(devUserId: null);

    final response = await app.get('/health');

    expect(response.statusCode, 200);
    expect(await jsonBody(response), {'status': 'ok'});
  });

  test('GET /health/database reports a reachable database', () async {
    final app = TestApp(devUserId: null);

    final response = await app.get('/health/database');

    expect(response.statusCode, 200);
    expect(await jsonBody(response), {'status': 'ok', 'database': 'reachable'});
  });

  test('GET /health/database answers 503 without leaking details', () async {
    final app = TestApp(devUserId: null);
    app.databaseHealth.failWith = const DatabaseUnavailableException('connect to 10.0.0.5:3306 refused');

    final response = await app.get('/health/database');
    final body = await jsonBody(response);

    expect(response.statusCode, 503);
    expect(body, {
      'error': {'code': 'database_unavailable', 'message': 'The database is currently unavailable.'},
    });
  });
}
