import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'server_config.dart';

// Infrastructure smoke test only. No Jitan API, authentication or database.
const version = '0.1.2-network-test';
const page = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Jitan network test</title>
<style>
body{margin:0;background:#faf9f6;color:#18201f;font:18px system-ui,sans-serif;
display:grid;min-height:100vh;place-items:center}
main{margin:24px;padding:40px;max-width:580px;background:white;
border:1px solid #e5e5e0;border-radius:16px}
.brand{color:#e94b35;font-weight:700}h1{font-size:40px;margin:20px 0}
p{line-height:1.6}small{color:#626866}
</style></head><body><main><div class="brand">JITAN</div>
<h1>Hello jitan!!</h1><p>The Jitan Linux network-test server is reachable.</p>
<p>This page is served directly by the standalone Dart executable.</p>
<small>Network test only · no application data or database connection.</small>
</main></body></html>''';

void logEvent(String event, [Map<String, Object> fields = const {}]) {
  stdout.writeln(
    jsonEncode({
      'time': DateTime.now().toUtc().toIso8601String(),
      'event': event,
      ...fields,
    }),
  );
}

Future<void> main() async {
  final ServerConfig config;
  final SecurityContext? tls;
  try {
    config = ServerConfig.load(Platform.environment);
    tls = config.securityContext();
  } on ConfigException catch (error) {
    stderr.writeln(error.message);
    exitCode = 78;
    return;
  }

  final servers = <HttpServer>[];
  try {
    for (final address in config.addresses) {
      final server = tls == null
          ? await HttpServer.bind(address, config.port)
          : await HttpServer.bindSecure(address, config.port, tls);
      server.idleTimeout = const Duration(seconds: 15);
      server.autoCompress = true;
      servers.add(server);
    }
  } catch (_) {
    for (final server in servers) {
      await server.close(force: true);
    }
    stderr.writeln(
      'Cannot bind HTTP listener. Check the address, port and permissions.',
    );
    exitCode = 1;
    return;
  }
  final signals = <StreamSubscription<ProcessSignal>>[];
  var stopping = false;
  Future<void> stop() async {
    if (stopping) return;
    stopping = true;
    logEvent('shutdown');
    for (final signal in signals) {
      await signal.cancel();
    }
    await Future.wait(
      servers.map(
        (server) => server
            .close()
            .then<void>((_) {})
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () async {
                await server.close(force: true);
              },
            ),
      ),
    );
    logEvent('stopped');
  }

  signals.add(ProcessSignal.sigint.watch().listen((_) => unawaited(stop())));
  if (!Platform.isWindows) {
    signals.add(ProcessSignal.sigterm.watch().listen((_) => unawaited(stop())));
  }
  logEvent('started', {
    'version': version,
    'hosts': config.addresses.map((address) => address.address).toList(),
    'port': config.port,
    'protocol': config.https ? 'https' : 'http',
  });
  await Future.wait(
    servers.map((server) async {
      await for (final request in server) {
        unawaited(respond(request));
      }
    }),
  );
}

Future<void> respond(HttpRequest request) async {
  final response = request.response;
  response.headers
    ..set('cache-control', 'no-store')
    ..set('x-content-type-options', 'nosniff')
    ..set(
      'content-security-policy',
      "default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'",
    );
  String body;
  if (request.method != 'GET' && request.method != 'HEAD') {
    response.statusCode = HttpStatus.methodNotAllowed;
    response.headers.set('allow', 'GET, HEAD');
    response.headers.contentType = ContentType.text;
    body = 'Method not allowed\n';
  } else if (request.uri.path == '/') {
    response.headers.contentType = ContentType.html;
    body = page;
  } else if ({
    '/health',
    '/health/live',
    '/health/ready',
  }.contains(request.uri.path)) {
    response.headers.contentType = ContentType.json;
    body = jsonEncode({'status': 'ok', 'mode': 'network-test'});
  } else {
    response.statusCode = HttpStatus.notFound;
    response.headers.contentType = ContentType.text;
    body = 'Not found\n';
  }
  response.headers.set('connection', 'close');
  response.contentLength = utf8.encode(body).length;
  try {
    if (request.method != 'HEAD') response.write(body);
    await response.close();
  } on IOException {
    // A disconnected client must not bring down the listener.
  }
  // Never record query strings, headers or request bodies.
  logEvent('request', {'status': response.statusCode});
}
