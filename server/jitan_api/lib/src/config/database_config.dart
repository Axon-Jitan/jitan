/// Connection settings for the MySQL database.
class DatabaseConfig {
  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.name,
    required this.user,
    required this.password,
    required this.secure,
  });

  final String host;
  final int port;
  final String name;
  final String user;
  final String password;

  /// Use TLS to the database server.
  final bool secure;

  /// Safe for logs: never includes the password.
  @override
  String toString() => 'DatabaseConfig($user@$host:$port/$name, secure: $secure)';
}
