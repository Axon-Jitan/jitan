import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/listener_config.dart';
import 'package:test/test.dart';

List<String> _addresses(ListenerConfig config) => [for (final a in config.addresses) a.address];

void main() {
  test('defaults: 127.0.0.1:8080 over HTTP', () {
    final config = ListenerConfig.from();
    expect(_addresses(config), ['127.0.0.1']);
    expect(config.port, 8080);
    expect(config.https, isFalse);
    expect(config.securityContext(), isNull);
  });

  test("a specific IPv4 address also opens 127.0.0.1 (IT's request)", () {
    expect(_addresses(ListenerConfig.from(host: '10.1.101.65')), ['10.1.101.65', '127.0.0.1']);
  });

  test('0.0.0.0, localhost and 127.0.0.1 open one listener', () {
    expect(_addresses(ListenerConfig.from(host: '0.0.0.0')), ['0.0.0.0']);
    expect(_addresses(ListenerConfig.from(host: 'localhost')), ['127.0.0.1']);
    expect(_addresses(ListenerConfig.from(host: '127.0.0.1')), ['127.0.0.1']);
  });

  test('a host name or an invalid port refuses to start', () {
    expect(() => ListenerConfig.from(host: 'agapp05'), throwsA(isA<ConfigException>()));
    for (final port in ['0', '65536', 'http']) {
      expect(() => ListenerConfig.from(port: port), throwsA(isA<ConfigException>()), reason: port);
    }
  });

  test('HTTPS needs both TLS_CERT and TLS_KEY', () {
    expect(() => ListenerConfig.from(certificateFile: '/etc/jitan/tls/a.crt'), throwsA(isA<ConfigException>()));
    expect(() => ListenerConfig.from(privateKeyFile: '/etc/jitan/tls/a.key'), throwsA(isA<ConfigException>()));
  });

  test('unreadable certificate files stop startup, with no HTTP fallback', () {
    final config = ListenerConfig.from(certificateFile: 'missing.crt', privateKeyFile: 'missing.key');
    expect(config.https, isTrue);
    expect(config.securityContext, throwsA(isA<ConfigException>()));
  });

  test('description for logs', () {
    expect(ListenerConfig.from(host: '10.1.101.65', port: '8080').toString(), 'http on 10.1.101.65, 127.0.0.1 port 8080');
  });
}
