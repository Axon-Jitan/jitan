import 'package:http/http.dart' as http;

import 'certificate_pin.dart';

/// Build-time configuration, passed with `--dart-define`.
class EmployeeConfig {
  const EmployeeConfig({required this.apiBaseUri, this.certificateSha256});

  /// Where the Jitan API lives, e.g. `https://jitan.example.com/api/`.
  /// Required; there is no default, so a misconfigured build fails visibly
  /// instead of calling the wrong server.
  final Uri apiBaseUri;

  /// SHA-256 fingerprint of the API server's own certificate, when no public
  /// authority issued it ([CertificatePin]); `null` otherwise.
  final String? certificateSha256;

  static const _apiBaseUrl = String.fromEnvironment('JITAN_API_BASE_URL');
  static const _certificateSha256 = String.fromEnvironment('JITAN_API_CERT_SHA256');

  /// `null` when `JITAN_API_BASE_URL` is missing or not an absolute URL.
  static EmployeeConfig? fromEnvironment() => parse(_apiBaseUrl, certificateSha256: _certificateSha256);

  static EmployeeConfig? parse(String raw, {String certificateSha256 = ''}) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed.endsWith('/') ? trimmed : '$trimmed/');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final pin = certificateSha256.trim();
    return EmployeeConfig(apiBaseUri: uri, certificateSha256: pin.isEmpty ? null : pin);
  }

  /// The HTTP client for the API: pinned to the server's certificate when
  /// one was given, the phone's usual checks otherwise.
  http.Client httpClient() {
    final pin = certificateSha256;
    if (pin == null) return http.Client();
    return CertificatePin(host: apiBaseUri.host, port: apiBaseUri.port, sha256Fingerprint: pin).client();
  }
}
