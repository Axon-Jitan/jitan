import 'package:jitan_api/src/http/strict_transport_middleware.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  test('every answer tells the browser to use only HTTPS (review I2)', () async {
    final handler = const Pipeline()
        .addMiddleware(strictTransportMiddleware())
        .addHandler((_) => Response.notFound('none'));

    final response = await handler(Request('GET', Uri.parse('https://jitan.test/nothing')));

    expect(response.statusCode, 404);
    expect(response.headers[strictTransportHeader], 'max-age=31536000');
  });
}
