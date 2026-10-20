import 'dart:io';

import 'package:crypto/crypto.dart';

import '../config/config_exception.dart';
import '../config/database_config.dart';

/// How the MySQL server certificate is checked (SEC-01).
///
/// The driver (mysql_client_plus 0.1.3) accepts **any** certificate unless it
/// is given a security context and a bad-certificate callback, so both are
/// always passed here:
///
/// - **CA file:** only that CA is trusted; a certificate that doesn't chain
///   to it, or doesn't match the address, fails the handshake. MySQL's
///   auto-generated certificates name no host, so this needs a certificate
///   IT issues for the database's address.
/// - **Fingerprints:** nothing is trusted by default. The TLS layer calls the
///   callback once for every certificate in the chain it can't verify (for
///   MySQL's auto-generated pair: the CA, then the server certificate), and
///   each one must be pinned. Nobody without the pinned keys can produce a
///   chain that passes. When IT renews the certificates, the fingerprints
///   change with them.
/// - **Neither** (development only, see AppConfig): encrypted but unverified.
class DatabaseTls {
  const DatabaseTls._(this.context, this.onBadCertificate);

  factory DatabaseTls.of(DatabaseConfig config) {
    if (!config.secure) return const DatabaseTls._(null, null);
    if (config.tlsCaFile case final caFile?) {
      final SecurityContext context;
      try {
        context = SecurityContext(withTrustedRoots: false)
          ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2
          ..setTrustedCertificates(caFile);
      } catch (_) {
        throw ConfigException('Cannot load JITAN_DB_TLS_CA_FILE ($caFile): it must be a readable PEM file.');
      }
      return DatabaseTls._(context, _refuse);
    }
    final pinned = config.tlsFingerprints;
    if (pinned.isNotEmpty) {
      return DatabaseTls._(
        SecurityContext(withTrustedRoots: false)..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2,
        (certificate) => pinned.contains(certificateFingerprint(certificate.der)),
      );
    }
    return const DatabaseTls._(null, _acceptUnverified);
  }

  final SecurityContext? context;
  final bool Function(X509Certificate certificate)? onBadCertificate;

  static bool _refuse(X509Certificate certificate) => false;
  static bool _acceptUnverified(X509Certificate certificate) => true;
}

/// SHA-256 of a DER certificate as 64 lowercase hex digits.
String certificateFingerprint(List<int> der) => sha256.convert(der).toString();

/// Accepts `70:26:23:…`, `702623…` or with spaces, any case, as printed by
/// `openssl x509 -fingerprint -sha256`; `null` when it isn't a SHA-256
/// fingerprint.
String? normalizeFingerprint(String raw) {
  final hex = raw.replaceAll(RegExp(r'[\s:]'), '').toLowerCase();
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(hex) ? hex : null;
}
