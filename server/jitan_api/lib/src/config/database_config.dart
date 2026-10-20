/// Connection settings for the MySQL database.
class DatabaseConfig {
  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.name,
    required this.user,
    required this.password,
    required this.secure,
    this.tlsCaFile,
    this.tlsFingerprints = const {},
  }) : assert(tlsCaFile == null || tlsFingerprints.length == 0, 'choose one way to verify the certificate');

  final String host;
  final int port;
  final String name;
  final String user;
  final String password;

  /// Use TLS to the database server.
  final bool secure;

  /// PEM file of the CA that issued the MySQL server certificate
  /// (`JITAN_DB_TLS_CA_FILE`). The certificate must chain to it.
  final String? tlsCaFile;

  /// SHA-256 fingerprints of the certificates the MySQL server presents,
  /// each 64 lowercase hex digits (`JITAN_DB_TLS_FINGERPRINTS`). For MySQL's
  /// auto-generated certificates: the CA and the server certificate. Any
  /// other certificate is refused (DatabaseTls).
  final Set<String> tlsFingerprints;

  /// Whether the server certificate is checked. Without it, TLS still
  /// encrypts but anyone in the network path could impersonate the database.
  bool get verifiesCertificate => tlsCaFile != null || tlsFingerprints.isNotEmpty;

  /// Safe for logs: never includes the password.
  @override
  String toString() {
    final tls = !secure
        ? 'no TLS'
        : tlsCaFile != null
            ? 'TLS, CA file $tlsCaFile'
            : tlsFingerprints.isNotEmpty
                ? 'TLS, ${tlsFingerprints.length} pinned certificate(s)'
                : 'TLS, certificate NOT verified';
    return 'DatabaseConfig($user@$host:$port/$name, $tls)';
  }
}
