/// Invalid or unsafe server configuration. Thrown at startup; the server
/// does not start.
class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}
