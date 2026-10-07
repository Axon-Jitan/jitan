import 'app_environment.dart';
import 'config_exception.dart';
import 'database_config.dart';

/// Server configuration, read once at startup from environment variables.
///
/// Secrets come only from the environment (or a git-ignored `.env` in
/// development). See `.env.example` for every variable.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.httpHost,
    required this.httpPort,
    required this.corsOrigins,
    required this.database,
    required this.devUserId,
  });

  /// Builds the configuration from [env] and enforces the safety rules:
  ///
  /// - `JITAN_ENV` unset means production.
  /// - In production, any non-empty `JITAN_DEV_*` variable is a startup error,
  ///   so the development identity cannot be enabled by accident.
  factory AppConfig.fromEnvironment(Map<String, String> env) {
    final environment = AppEnvironment.parse(env['JITAN_ENV']);

    if (!environment.allowsDevelopmentMechanisms) {
      final devKeys = env.entries
          .where((e) => e.key.startsWith(_devPrefix) && e.value.trim().isNotEmpty)
          .map((e) => e.key)
          .toList()
        ..sort();
      if (devKeys.isNotEmpty) {
        throw ConfigException(
          'Development-only variables are set in production: ${devKeys.join(', ')}. '
          'Remove them or set JITAN_ENV=development.',
        );
      }
    }

    return AppConfig(
      environment: environment,
      httpHost: _optional(env, 'JITAN_HTTP_HOST') ?? '127.0.0.1',
      httpPort: _port(env, 'JITAN_HTTP_PORT', fallback: 8080),
      corsOrigins: (_optional(env, 'JITAN_CORS_ORIGINS') ?? '')
          .split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty)
          .toSet(),
      database: DatabaseConfig(
        host: _required(env, 'JITAN_DB_HOST'),
        port: _port(env, 'JITAN_DB_PORT', fallback: 3306),
        name: _required(env, 'JITAN_DB_NAME'),
        user: _required(env, 'JITAN_DB_USER'),
        password: env['JITAN_DB_PASSWORD'] ?? '',
        secure: _bool(env, 'JITAN_DB_SECURE', fallback: true),
      ),
      devUserId: environment.allowsDevelopmentMechanisms
          ? _optionalPositiveInt(env, 'JITAN_DEV_USER_ID')
          : null,
    );
  }

  static const _devPrefix = 'JITAN_DEV_';

  final AppEnvironment environment;
  final String httpHost;
  final int httpPort;

  /// Browser origins allowed by CORS. Empty in production (same-origin via Nginx).
  final Set<String> corsOrigins;

  final DatabaseConfig database;

  /// `tblUser.userID` used as the acting user by the development identity.
  /// Always `null` in production.
  final int? devUserId;

  static String? _optional(Map<String, String> env, String key) {
    final value = env[key]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  static String _required(Map<String, String> env, String key) {
    final value = _optional(env, key);
    if (value == null) throw ConfigException('$key is required.');
    return value;
  }

  static int _port(Map<String, String> env, String key, {required int fallback}) {
    final raw = _optional(env, key);
    if (raw == null) return fallback;
    final port = int.tryParse(raw);
    if (port == null || port < 1 || port > 65535) {
      throw ConfigException('$key must be a port number (1-65535); got "$raw".');
    }
    return port;
  }

  static bool _bool(Map<String, String> env, String key, {required bool fallback}) {
    final raw = _optional(env, key)?.toLowerCase();
    if (raw == null) return fallback;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    throw ConfigException('$key must be true or false; got "$raw".');
  }

  static int? _optionalPositiveInt(Map<String, String> env, String key) {
    final raw = _optional(env, key);
    if (raw == null) return null;
    final value = int.tryParse(raw);
    if (value == null || value <= 0) {
      throw ConfigException('$key must be a positive integer; got "$raw".');
    }
    return value;
  }
}
