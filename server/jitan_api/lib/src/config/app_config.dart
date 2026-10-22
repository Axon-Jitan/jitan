import '../auth/password_hasher.dart';
import '../database/database_tls.dart';
import 'app_environment.dart';
import 'config_exception.dart';
import 'config_sources.dart';
import 'database_config.dart';
import 'listener_config.dart';

/// Server configuration, read once at startup from the environment, IT's
/// `/etc/jitan/app.env` and a development `.env` ([ConfigSources]).
///
/// Secrets come only from those sources, never from the repository. See
/// `.env.example` and docs/DEPLOYMENT_CONFIGURATION.md for every setting.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.listener,
    required this.corsOrigins,
    required this.database,
    required this.devUserId,
    this.devGroupSchedules = false,
    required this.sessionSecret,
    required this.sessionLifetime,
    required this.passwordHashing,
    this.timeZone = defaultTimeZone,
  });

  /// The configuration from one map of settings (tests and tools).
  factory AppConfig.fromEnvironment(Map<String, String> env) => AppConfig.fromSources(ConfigSources([env]));

  /// Builds the configuration from [sources] and enforces the safety rules:
  ///
  /// - `JITAN_ENV` unset means production.
  /// - In production, any non-empty `JITAN_DEV_*` setting, in any source, is
  ///   a startup error, so the development identity cannot be enabled by
  ///   accident.
  /// - In production, `JITAN_SESSION_SECRET` (at least 32 characters) is
  ///   required: without it sessions could not be trusted across restarts.
  /// - In production, the database connection is encrypted and its
  ///   certificate verified ([_database]).
  factory AppConfig.fromSources(ConfigSources sources) {
    final environment = AppEnvironment.parse(sources.value(['JITAN_ENV']));

    if (!environment.allowsDevelopmentMechanisms) {
      final devKeys = sources.keysWithValues.where((key) => key.startsWith(_devPrefix)).toList()..sort();
      if (devKeys.isNotEmpty) {
        throw ConfigException(
          'Development-only variables are set in production: ${devKeys.join(', ')}. '
          'Remove them or set JITAN_ENV=development.',
        );
      }
    }

    return AppConfig(
      environment: environment,
      listener: ListenerConfig.from(
        host: sources.value(['BIND_ADDRESS', 'HOST', 'JITAN_HTTP_HOST']),
        port: sources.value(['PORT', 'JITAN_HTTP_PORT']),
        certificateFile: sources.value(['TLS_CERT']),
        privateKeyFile: sources.value(['TLS_KEY']),
      ),
      corsOrigins: (sources.value(['JITAN_CORS_ORIGINS']) ?? '')
          .split(',')
          .map((origin) => origin.trim())
          .where((origin) => origin.isNotEmpty)
          .toSet(),
      database: _database(sources, environment),
      devUserId: environment.allowsDevelopmentMechanisms
          ? _optionalPositiveInt(sources, 'JITAN_DEV_USER_ID')
          : null,
      devGroupSchedules: environment.allowsDevelopmentMechanisms && _flag(sources, 'JITAN_DEV_GROUP_SCHEDULES'),
      sessionSecret: _sessionSecret(sources, environment),
      sessionLifetime: Duration(days: _optionalPositiveInt(sources, 'JITAN_SESSION_LIFETIME_DAYS') ?? 30),
      passwordHashing: _passwordHashing(sources),
      timeZone: sources.value(['JITAN_TIMEZONE']) ?? defaultTimeZone,
    );
  }

  /// IT's `DB_*` names first, then Jitan's `JITAN_DB_*` names.
  ///
  /// TLS (SEC-01): `JITAN_DB_SECURE` (default true) and one way to verify the
  /// server certificate, `JITAN_DB_TLS_CA_FILE` or `JITAN_DB_TLS_FINGERPRINTS`
  /// (SHA-256, comma-separated). Production refuses an unencrypted or
  /// unverified connection; development allows it, and the server warns.
  static DatabaseConfig _database(ConfigSources sources, AppEnvironment environment) {
    final secure = _bool(sources, 'JITAN_DB_SECURE', fallback: true);
    final caFile = sources.value(['JITAN_DB_TLS_CA_FILE']);
    final fingerprints = {
      for (final raw in (sources.value(['JITAN_DB_TLS_FINGERPRINTS']) ?? '').split(','))
        if (raw.trim().isNotEmpty)
          normalizeFingerprint(raw) ??
              (throw const ConfigException(
                'JITAN_DB_TLS_FINGERPRINTS must be SHA-256 fingerprints (64 hex digits, colons allowed), '
                'separated by commas.',
              )),
    };
    if (caFile != null && fingerprints.isNotEmpty) {
      throw const ConfigException('Set JITAN_DB_TLS_CA_FILE or JITAN_DB_TLS_FINGERPRINTS, not both.');
    }
    if (!secure && (caFile != null || fingerprints.isNotEmpty)) {
      throw const ConfigException('JITAN_DB_TLS_CA_FILE and JITAN_DB_TLS_FINGERPRINTS need JITAN_DB_SECURE=true.');
    }
    if (!environment.allowsDevelopmentMechanisms) {
      if (!secure) throw const ConfigException('JITAN_DB_SECURE=false is not allowed in production.');
      if (caFile == null && fingerprints.isEmpty) {
        throw const ConfigException(
          'Production needs the database certificate verified: set JITAN_DB_TLS_FINGERPRINTS or JITAN_DB_TLS_CA_FILE.',
        );
      }
    }
    return DatabaseConfig(
      host: _required(sources, ['DB_HOST', 'JITAN_DB_HOST']),
      port: _port(sources, ['DB_PORT', 'JITAN_DB_PORT'], fallback: 3306),
      name: _required(sources, ['DB_NAME', 'JITAN_DB_NAME']),
      user: _required(sources, ['DB_USER', 'JITAN_DB_USER']),
      password: sources.untrimmed(['DB_PASS', 'JITAN_DB_PASSWORD']) ?? '',
      secure: secure,
      tlsCaFile: caFile,
      tlsFingerprints: fingerprints,
    );
  }

  static const _minSessionSecretLength = 32;

  static String? _sessionSecret(ConfigSources sources, AppEnvironment environment) {
    final secret = sources.value(['JITAN_SESSION_SECRET']);
    if (secret == null) {
      if (environment.allowsDevelopmentMechanisms) return null;
      throw const ConfigException('JITAN_SESSION_SECRET is required in production.');
    }
    if (secret.length < _minSessionSecretLength) {
      throw const ConfigException('JITAN_SESSION_SECRET must be at least $_minSessionSecretLength characters.');
    }
    return secret;
  }

  static Argon2idParameters _passwordHashing(ConfigSources sources) {
    const recommended = Argon2idParameters.recommended;
    final parameters = Argon2idParameters(
      memoryKiB: _optionalPositiveInt(sources, 'JITAN_ARGON2_MEMORY_KIB') ?? recommended.memoryKiB,
      iterations: _optionalPositiveInt(sources, 'JITAN_ARGON2_ITERATIONS') ?? recommended.iterations,
      parallelism: _optionalPositiveInt(sources, 'JITAN_ARGON2_PARALLELISM') ?? recommended.parallelism,
    );
    if (!parameters.isWithinBounds) {
      throw ConfigException('Argon2id parameters out of bounds: $parameters.');
    }
    return parameters;
  }

  static const _devPrefix = 'JITAN_DEV_';

  final AppEnvironment environment;

  /// Address(es), port and HTTPS certificate the API listens with.
  final ListenerConfig listener;

  /// Browser origins allowed by CORS. Empty when clients are same-origin.
  final Set<String> corsOrigins;

  final DatabaseConfig database;

  /// `tblUser.userID` used as the acting user by the development identity.
  /// Always `null` in production.
  final int? devUserId;

  /// PROPOSAL (ERD_GAPS GAP-15): groups own their schedule through
  /// `tblGroupSchedule`, a table only in the local development database.
  /// `JITAN_DEV_GROUP_SCHEDULES=true`; always `false` in production (any
  /// `JITAN_DEV_*` setting stops the server there).
  final bool devGroupSchedules;

  /// Key that signs session tokens. `null` only in development/test, where a
  /// random one is generated at startup (sessions then end on restart).
  final String? sessionSecret;

  /// How long a session token is valid (PRODUCT-CLARIFY-SESSION-LIFETIME).
  final Duration sessionLifetime;

  /// Argon2id parameters for new password hashes.
  final Argon2idParameters passwordHashing;

  /// The workplace time zone (IANA name, `JITAN_TIMEZONE`): registrations are
  /// stored in UTC and compared with schedules in this local time
  /// (TIME_ENGINE_ANALYSIS D9). Checked when the server starts.
  final String timeZone;

  static const defaultTimeZone = 'Europe/Brussels';

  static String _required(ConfigSources sources, List<String> keys) =>
      sources.value(keys) ?? (throw ConfigException('${keys.join(' or ')} is required.'));

  /// The message names the setting, never its value.
  static int _port(ConfigSources sources, List<String> keys, {required int fallback}) {
    final raw = sources.value(keys);
    if (raw == null) return fallback;
    final port = int.tryParse(raw);
    if (port == null || port < 1 || port > 65535) {
      throw ConfigException('${keys.join(' or ')} must be a port number (1-65535).');
    }
    return port;
  }

  static bool _bool(ConfigSources sources, String key, {required bool fallback}) {
    final raw = sources.value([key])?.toLowerCase();
    if (raw == null) return fallback;
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    throw ConfigException('$key must be true or false; got "$raw".');
  }

  /// `true` or `false` (default `false`).
  static bool _flag(ConfigSources sources, String key) => switch (sources.value([key])) {
    null || 'false' => false,
    'true' => true,
    final raw => throw ConfigException('$key must be true or false; got "$raw".'),
  };

  static int? _optionalPositiveInt(ConfigSources sources, String key) {
    final raw = sources.value([key]);
    if (raw == null) return null;
    final value = int.tryParse(raw);
    if (value == null || value <= 0) {
      throw ConfigException('$key must be a positive integer; got "$raw".');
    }
    return value;
  }
}
