import 'dart:convert';
import 'dart:io';

import 'package:jitan_api/src/web/embedded_web_assets.dart';
import 'package:jitan_api/src/web/web_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// The HR website built into the executable: its files on the API's address,
/// everything else on to the API.
void main() {
  String packed(String text) => base64.encode(gzip.encode(utf8.encode(text)));

  final web = WebRoutes({
    'index.html': packed('<html>Jitan HR</html>'),
    'main.dart.js': packed('main();'),
    'canvaskit/canvaskit.wasm': packed('wasm'),
  });

  /// The website first, then a stand-in for the API.
  final app = Cascade().add(web.call).add((request) => Response.ok('api ${request.method} /${request.url.path}')).handler;

  Request get(String path, {String method = 'GET', String? acceptEncoding}) => Request(
    method,
    Uri.parse('https://jitan.test/$path'),
    headers: {'accept-encoding': ?acceptEncoding},
  );

  test('the page at "/" and its files, with the policy agreed with IT', () async {
    final page = await app(get(''));
    expect(page.statusCode, 200);
    expect(await page.readAsString(), '<html>Jitan HR</html>');
    expect(page.headers['content-type'], 'text/html; charset=utf-8');
    expect(page.headers['content-security-policy'], WebRoutes.contentSecurityPolicy);
    expect(page.headers['content-security-policy'], contains("connect-src 'self'"));
    expect(page.headers['x-content-type-options'], 'nosniff');
    expect(page.headers['cache-control'], 'no-cache');

    final wasm = await app(get('canvaskit/canvaskit.wasm'));
    expect(wasm.headers['content-type'], 'application/wasm');
    expect(await wasm.readAsString(), 'wasm');
  });

  test('compressed when the browser accepts it, plain otherwise', () async {
    final zipped = await app(get('main.dart.js', acceptEncoding: 'gzip, deflate, br'));
    expect(zipped.headers['content-encoding'], 'gzip');
    expect(utf8.decode(gzip.decode(await zipped.read().expand((b) => b).toList())), 'main();');

    final plain = await app(get('main.dart.js'));
    expect(plain.headers['content-encoding'], isNull);
    expect(await plain.readAsString(), 'main();');
  });

  test('HEAD answers without a body', () async {
    final head = await app(get('main.dart.js', method: 'HEAD'));
    expect(head.statusCode, 200);
    expect(await head.readAsString(), isEmpty);
  });

  test('everything else goes on to the API: other paths, other methods', () async {
    expect(await (await app(get('me'))).readAsString(), 'api GET /me');
    expect(await (await app(get('companies/1/employees'))).readAsString(), 'api GET /companies/1/employees');
    expect(await (await app(get('index.html', method: 'POST'))).readAsString(), 'api POST /index.html');
  });

  test('the repository holds no website: a plain build serves only the API', () {
    expect(embeddedWebAssets, isEmpty, reason: 'tool/build_release.dart fills it only for the release it compiles');
  });
}
