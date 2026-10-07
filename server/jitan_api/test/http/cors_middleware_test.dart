import 'package:test/test.dart';

import '../support/test_app.dart';

void main() {
  test('adds CORS headers for an allowed origin, including on errors', () async {
    final app = TestApp(devUserId: null, corsOrigins: {'http://localhost:5000'});

    final response = await app.get('/companies', headers: {'origin': 'http://localhost:5000'});

    expect(response.statusCode, 401);
    expect(response.headers['access-control-allow-origin'], 'http://localhost:5000');
  });

  test('adds no CORS headers for other origins', () async {
    final app = TestApp(corsOrigins: {'http://localhost:5000'});

    final response = await app.get('/health', headers: {'origin': 'http://evil.example'});

    expect(response.headers.containsKey('access-control-allow-origin'), isFalse);
  });
}
