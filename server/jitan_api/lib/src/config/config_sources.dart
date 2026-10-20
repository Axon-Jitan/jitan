import 'dart:io';

import 'config_exception.dart';
import 'env_file.dart';

/// Where the server's settings come from, highest priority first
/// (docs/DEPLOYMENT_CONFIGURATION.md):
///
/// 1. the process environment (e.g. systemd `Environment=`),
/// 2. IT's configuration file, `/etc/jitan/app.env`, or the file named by
///    `JITAN_CONFIG_FILE`,
/// 3. a `.env` in the working directory (development convenience).
///
/// A setting can have several names (IT's first, then Jitan's legacy one).
/// [value] looks for every name in the highest source before moving to the
/// next, so a legacy name in the environment still overrides IT's name in
/// the file.
class ConfigSources {
  const ConfigSources(this._sources);

  /// The sources, highest priority first.
  final List<Map<String, String>> _sources;

  /// IT's default configuration file.
  static const defaultConfigFile = '/etc/jitan/app.env';

  /// Reads the sources. The default file may be absent (e.g. on a
  /// development machine); a file named by `JITAN_CONFIG_FILE` must exist,
  /// and a file that exists but can't be read (permissions) is an error,
  /// never silently skipped.
  static ConfigSources load(
    Map<String, String> environment, {
    String defaultFile = defaultConfigFile,
    String developmentFile = '.env',
  }) {
    final explicit = environment['JITAN_CONFIG_FILE'];
    if (explicit != null && explicit.trim().isEmpty) {
      throw const ConfigException('JITAN_CONFIG_FILE must name a configuration file.');
    }
    return ConfigSources([
      environment,
      _read(explicit ?? defaultFile, required: explicit != null),
      _read(developmentFile, required: false),
    ]);
  }

  static Map<String, String> _read(String path, {required bool required}) {
    final file = File(path);
    if (!required && !file.existsSync()) return const {};
    try {
      return parseEnvFile(file.readAsLinesSync());
    } on FileSystemException {
      throw ConfigException(
        'Cannot read the configuration file $path. Check the path and the service account\'s permissions.',
      );
    } on FormatException catch (e) {
      throw ConfigException('Invalid configuration file $path: ${e.message}');
    }
  }

  /// The first of [keys] found, looking in the highest source first; `null`
  /// when none is set or the value is blank.
  String? value(List<String> keys) {
    final trimmed = untrimmed(keys)?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Like [value] but exactly as written, for passwords, which may start or
  /// end with spaces.
  String? untrimmed(List<String> keys) {
    for (final source in _sources) {
      for (final key in keys) {
        if (source[key] case final raw?) return raw;
      }
    }
    return null;
  }

  /// Every key set (non-blank) in any source, e.g. for the production guard
  /// against development variables.
  Set<String> get keysWithValues => {
        for (final source in _sources)
          for (final MapEntry(:key, :value) in source.entries)
            if (value.trim().isNotEmpty) key,
      };
}
