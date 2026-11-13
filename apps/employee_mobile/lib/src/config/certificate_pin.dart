import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// The API server's own certificate, when no public authority issued it (IT's
/// `agapp05` is self-signed, 2026-11-13). Android's trust settings don't reach
/// Dart's network code, so the app checks it itself: a certificate the phone
/// doesn't trust is accepted only for the API's exact address and port, and only
/// when its SHA-256 fingerprint is the pinned one. Everything else is refused.
class CertificatePin {
  CertificatePin({required this.host, required this.port, required String sha256Fingerprint})
    : fingerprint = sha256Fingerprint.replaceAll(':', '').toLowerCase();

  final String host;
  final int port;

  /// Lowercase hex, no colons.
  final String fingerprint;

  /// Whether [der] (the certificate's bytes) is the pinned certificate, served
  /// by the API's address.
  bool accepts(List<int> der, String host, int port) =>
      host == this.host && port == this.port && sha256.convert(der).toString() == fingerprint;

  /// The HTTP client for the API: the phone's usual checks, plus this pin.
  http.Client client() => IOClient(HttpClient()..badCertificateCallback = (cert, host, port) => accepts(cert.der, host, port));
}
