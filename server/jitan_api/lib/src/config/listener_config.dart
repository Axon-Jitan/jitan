import 'dart:io';

import 'config_exception.dart';

/// Where the API listens, and whether it serves HTTPS itself
/// (docs/DEPLOYMENT_CONFIGURATION.md, "Listener and HTTPS contract").
class ListenerConfig {
  const ListenerConfig({required this.addresses, required this.port, this.certificateFile, this.privateKeyFile});

  /// From `BIND_ADDRESS`, `HOST` or `JITAN_HTTP_HOST` (an IP address or
  /// `localhost`; default `127.0.0.1`) and `PORT` or `JITAN_HTTP_PORT`
  /// (default 8080). A specific non-loopback IPv4 address also opens
  /// `127.0.0.1` on the same port, as IT asked; `0.0.0.0` already covers it.
  /// `TLS_CERT` and `TLS_KEY` together enable HTTPS; one without the other is
  /// an error, never a silent fallback to HTTP.
  factory ListenerConfig.from({String? host, String? port, String? certificateFile, String? privateKeyFile}) {
    final rawHost = host ?? '127.0.0.1';
    final address = InternetAddress.tryParse(rawHost == 'localhost' ? '127.0.0.1' : rawHost) ??
        (throw const ConfigException('BIND_ADDRESS (or HOST) must be an IP address or localhost.'));
    final portNumber = int.tryParse(port ?? '8080');
    if (portNumber == null || portNumber < 1 || portNumber > 65535) {
      throw const ConfigException('PORT must be a port number from 1 to 65535.');
    }
    if ((certificateFile == null) != (privateKeyFile == null)) {
      throw const ConfigException('Set both TLS_CERT and TLS_KEY to serve HTTPS (or neither for HTTP).');
    }
    return ListenerConfig(
      addresses: [
        address,
        if (address.type == InternetAddressType.IPv4 && !address.isLoopback && address.address != '0.0.0.0')
          InternetAddress.loopbackIPv4,
      ],
      port: portNumber,
      certificateFile: certificateFile,
      privateKeyFile: privateKeyFile,
    );
  }

  final List<InternetAddress> addresses;
  final int port;

  /// PEM certificate chain and unencrypted PEM private key (IT's paths).
  final String? certificateFile;
  final String? privateKeyFile;

  bool get https => certificateFile != null;

  /// The TLS context for HTTPS (TLS 1.2 or later), `null` for HTTP. Fails
  /// when the files can't be read or don't match: HTTPS is never replaced by
  /// HTTP. The message never contains file contents.
  SecurityContext? securityContext() {
    if (!https) return null;
    try {
      return SecurityContext()
        ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2
        ..useCertificateChain(certificateFile!)
        ..usePrivateKey(privateKeyFile!);
    } catch (_) {
      throw const ConfigException(
        'Cannot load TLS_CERT/TLS_KEY: check that both are readable PEM files, that the key matches the certificate '
        'and that the key is not encrypted. HTTPS was not started.',
      );
    }
  }

  /// Safe for logs.
  @override
  String toString() =>
      '${https ? 'https' : 'http'} on ${addresses.map((a) => a.address).join(', ')} port $port';
}
