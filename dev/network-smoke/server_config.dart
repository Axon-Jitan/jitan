import 'dart:io';

class ConfigException implements Exception {
  const ConfigException(this.message);
  final String message;
}

/// Only listener settings are consumed. DB_* entries remain unused by this demo.
class ServerConfig {
  ServerConfig._(this.addresses, this.port, this.certificate, this.privateKey);

  final List<InternetAddress> addresses;
  final int port;
  final String? certificate;
  final String? privateKey;
  bool get https => certificate != null;

  static ServerConfig load(Map<String, String> environment) {
    final explicitPath = environment['JITAN_CONFIG_FILE'];
    final path = explicitPath ?? '/etc/jitan/app.env';
    if (path.trim().isEmpty) {
      throw const ConfigException(
        'JITAN_CONFIG_FILE must name a configuration file.',
      );
    }
    final file = File(path);
    Map<String, String> values = {};
    try {
      values = parseConfig(file.readAsLinesSync());
    } on FileSystemException catch (error) {
      // Preserve the old environment-only invocation when no default file exists.
      // Permission errors and explicit missing files must fail closed.
      if (explicitPath != null || !{2, 3}.contains(error.osError?.errorCode)) {
        throw const ConfigException(
          'Cannot read configuration file. Check JITAN_CONFIG_FILE and service-account permissions.',
        );
      }
    }
    return ServerConfig.fromValues(values, environment);
  }

  factory ServerConfig.fromValues(
    Map<String, String> fileValues,
    Map<String, String> environment,
  ) {
    // Overrides are resolved per source so a legacy env override also takes
    // priority over a differently named file setting.
    String? value(List<String> keys) {
      for (final source in [environment, fileValues]) {
        for (final key in keys) {
          if (source.containsKey(key)) return source[key]!.trim();
        }
      }
      return null;
    }

    final host =
        value(['BIND_ADDRESS', 'HOST', 'JITAN_HTTP_HOST']) ?? '127.0.0.1';
    final address = InternetAddress.tryParse(
      host == 'localhost' ? '127.0.0.1' : host,
    );
    if (address == null) {
      throw const ConfigException(
        'BIND_ADDRESS (or HOST) must be an IP address or localhost.',
      );
    }
    final port = int.tryParse(value(['PORT', 'JITAN_HTTP_PORT']) ?? '8080');
    if (port == null || port < 1 || port > 65535) {
      throw const ConfigException('PORT must be an integer from 1 to 65535.');
    }
    final cert = value(['TLS_CERT']);
    final key = value(['TLS_KEY']);
    final certificate = cert == null || cert.isEmpty ? null : cert;
    final privateKey = key == null || key.isEmpty ? null : key;
    if ((certificate == null) != (privateKey == null)) {
      throw const ConfigException(
        'Set both TLS_CERT and TLS_KEY to enable HTTPS.',
      );
    }
    final addresses = [address];
    // A specific IPv4 interface and localhost are both available, as requested
    // by IT. A wildcard already includes localhost and must not be bound twice.
    if (address.type == InternetAddressType.IPv4 &&
        !address.isLoopback &&
        address.address != '0.0.0.0') {
      addresses.add(InternetAddress.loopbackIPv4);
    }
    return ServerConfig._(addresses, port, certificate, privateKey);
  }

  SecurityContext? securityContext() {
    if (!https) return null;
    try {
      return SecurityContext()
        ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2
        ..useCertificateChain(certificate!)
        ..usePrivateKey(privateKey!);
    } catch (_) {
      throw const ConfigException(
        'Cannot load TLS_CERT/TLS_KEY. Check readable PEM files, matching certificate/key, and an unencrypted private key. HTTPS was not started.',
      );
    }
  }
}

/// A deliberately small .env format: KEY=value, quotes, blank/comment lines.
/// Values are never evaluated, expanded or included in error messages.
Map<String, String> parseConfig(Iterable<String> lines) {
  final values = <String, String>{};
  var lineNumber = 0;
  for (final raw in lines) {
    lineNumber++;
    var line = raw.trim();
    if (lineNumber == 1) line = line.replaceFirst(RegExp(r'^\uFEFF'), '');
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trim();
    final separator = line.indexOf('=');
    if (separator <= 0) {
      throw ConfigException(
        'Invalid configuration syntax on line $lineNumber; expected KEY=value.',
      );
    }
    final key = line.substring(0, separator).trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
      throw ConfigException('Invalid configuration key on line $lineNumber.');
    }
    var value = line.substring(separator + 1).trim();
    if (value.startsWith('"') || value.startsWith("'")) {
      if (value.length < 2 || !value.endsWith(value[0])) {
        throw ConfigException(
          'Unclosed configuration quote on line $lineNumber.',
        );
      }
      value = value.substring(1, value.length - 1);
    }
    if (values.containsKey(key)) {
      throw ConfigException('Duplicate configuration key on line $lineNumber.');
    }
    values[key] = value;
  }
  return values;
}
