import 'dart:io';

import 'server_config.dart';

void check(bool condition, String name) {
  if (!condition) throw StateError('FAIL: $name');
}

void rejected(void Function() action, String name) {
  try {
    action();
  } on ConfigException catch (error) {
    check(!error.message.contains('secret-value'), '$name redacts values');
    return;
  }
  throw StateError('FAIL: $name must be rejected');
}

void main() {
  final values = parseConfig([
    '\uFEFF# IT config',
    'BIND_ADDRESS=10.1.101.65',
    'HOST=10.1.101.99',
    'PORT=8080',
    'TLS_CERT="/etc/jitan/tls/agapp05.crt"',
    "TLS_KEY='/etc/jitan/tls/agapp05.key'",
    'DB_PASS=secret-value=with#characters',
  ]);
  final config = ServerConfig.fromValues(values, {});
  check(
    config.addresses.map((a) => a.address).join(',') == '10.1.101.65,127.0.0.1',
    'specific IP plus loopback; BIND_ADDRESS wins',
  );
  check(config.port == 8080 && config.https, 'port and HTTPS');
  check(config.certificate == '/etc/jitan/tls/agapp05.crt', 'quoted cert');
  final override = ServerConfig.fromValues(values, {
    'JITAN_HTTP_HOST': '0.0.0.0',
    'JITAN_HTTP_PORT': '8090',
  });
  check(
    override.addresses.length == 1 && override.port == 8090,
    'legacy env overrides file; no duplicate wildcard',
  );
  check(
    ServerConfig.fromValues({'HOST': '127.0.0.1'}, {}).addresses.length == 1,
    'HOST fallback',
  );
  check(!ServerConfig.fromValues({}, {}).https, 'HTTP without cert settings');
  check(ServerConfig.fromValues({}, {}).port == 8080, 'legacy default port');
  rejected(
    () => ServerConfig.fromValues({'TLS_CERT': 'secret-value'}, {}),
    'partial TLS',
  );
  rejected(
    () => ServerConfig.fromValues({'PORT': 'secret-value'}, {}),
    'invalid port',
  );
  rejected(
    () => ServerConfig.fromValues({'BIND_ADDRESS': 'secret-value'}, {}),
    'invalid address',
  );
  rejected(() => parseConfig(['DB_PASS secret-value']), 'malformed line');
  rejected(() => parseConfig(['TLS_KEY="secret-value']), 'unclosed quote');
  rejected(() => parseConfig(['PORT=8080', 'PORT=8081']), 'duplicate key');

  final dir = Directory.systemTemp.createTempSync('jitan-config-check-');
  try {
    final file = File('${dir.path}/app.env')
      ..writeAsStringSync('HOST=127.0.0.1\nPORT=8181\n');
    check(
      ServerConfig.load({'JITAN_CONFIG_FILE': file.path}).port == 8181,
      'explicit config path',
    );
    file.writeAsStringSync('HOST=127.0.0.1\nPORT=8182\n');
    check(
      ServerConfig.load({'JITAN_CONFIG_FILE': file.path}).port == 8182,
      'file reread on restart',
    );
    rejected(
      () => ServerConfig.load({'JITAN_CONFIG_FILE': '${dir.path}/missing'}),
      'explicit missing file',
    );
  } finally {
    dir.deleteSync(recursive: true);
  }
  stdout.writeln(
    'PASS: config parsing, aliases, precedence, dual bind, restart settings, fail-closed errors and secret redaction.',
  );
}
