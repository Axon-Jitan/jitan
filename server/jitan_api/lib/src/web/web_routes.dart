import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Serves the HR website's files from the executable (DEPLOYMENT_CONFIGURATION:
/// one executable, the website and the API on the same address).
///
/// Only `GET` and `HEAD` of a file the website has, and `/` for its page.
/// Anything else answers 404, so the request goes on to the API: the
/// website's files (`index.html`, `main.dart.js`, `assets/…`, `canvaskit/…`)
/// share no path with the API's endpoints. The website routes with `#`, so
/// its own pages never reach the server.
///
/// Every file goes out with the Content-Security-Policy agreed with IT, so
/// only Jitan's own scripts run on the page that keeps HR's session.
class WebRoutes {
  /// [assets]: path → gzip-compressed, base64-encoded bytes
  /// ([embeddedWebAssets]).
  WebRoutes(Map<String, String> assets) : _assets = assets;

  final Map<String, String> _assets;

  /// The policy from DEPLOYMENT_CONFIGURATION ("Serving the HR web"), the
  /// API being on the same address (`connect-src 'self'`).
  static const contentSecurityPolicy =
      "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; "
      "img-src 'self' data: blob: https://api.mapbox.com; font-src 'self' data:; "
      "connect-src 'self' https://api.mapbox.com; worker-src 'self' blob:; manifest-src 'self'; "
      "base-uri 'self'; form-action 'none'; frame-ancestors 'none'";

  static const _types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'json': 'application/json',
    'wasm': 'application/wasm',
    'css': 'text/css; charset=utf-8',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'svg': 'image/svg+xml',
    'ico': 'image/x-icon',
    'otf': 'font/otf',
    'ttf': 'font/ttf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'bin': 'application/octet-stream',
    'frag': 'application/octet-stream',
  };

  Response call(Request request) {
    if (request.method != 'GET' && request.method != 'HEAD') return Response.notFound(null);
    final path = request.url.path.isEmpty ? 'index.html' : request.url.path;
    final encoded = _assets[path];
    if (encoded == null) return Response.notFound(null);

    final compressed = base64.decode(encoded);
    final acceptsGzip = (request.headers[HttpHeaders.acceptEncodingHeader] ?? '').contains('gzip');
    final body = acceptsGzip ? compressed : gzip.decode(compressed);
    final extension = path.contains('.') ? path.substring(path.lastIndexOf('.') + 1) : '';
    return Response.ok(
      request.method == 'HEAD' ? null : body,
      headers: {
        HttpHeaders.contentTypeHeader: _types[extension] ?? 'application/octet-stream',
        HttpHeaders.contentLengthHeader: '${body.length}',
        if (acceptsGzip) HttpHeaders.contentEncodingHeader: 'gzip',
        HttpHeaders.varyHeader: 'Accept-Encoding',
        // A new release replaces the files under the same names: the browser
        // checks each time, so HR never runs half an old website.
        HttpHeaders.cacheControlHeader: 'no-cache',
        'content-security-policy': contentSecurityPolicy,
        'x-content-type-options': 'nosniff',
        'referrer-policy': 'no-referrer',
      },
    );
  }
}
