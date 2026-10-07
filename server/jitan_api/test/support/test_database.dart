import 'dart:io';

import 'package:jitan_api/src/config/database_config.dart';
import 'package:jitan_api/src/config/env_file.dart';
import 'package:jitan_api/src/database/database.dart';

/// Connection to the **development/test** database for integration tests.
///
/// Configured with `JITAN_TEST_DB_*` variables (environment, or a git-ignored
/// `.env.test` next to pubspec.yaml). Never point these at production:
/// tests insert and remove `[DEV-TEST]` fixtures.
class TestDatabase {
  TestDatabase._(this.config);

  final DatabaseConfig config;

  /// Reason integration tests are skipped, or `null` when configured.
  static String? get skipReason =>
      _load() == null ? 'Set JITAN_TEST_DB_HOST/NAME/USER/PASSWORD (or .env.test) to run.' : null;

  static Database connect({int maxConnections = 2}) => Database.connect(_load()!.config, maxConnections: maxConnections);

  static TestDatabase? _load() {
    final file = File('.env.test');
    final env = {if (file.existsSync()) ...parseEnvFile(file.readAsLinesSync()), ...Platform.environment};
    String? read(String key) {
      final value = env['JITAN_TEST_DB_$key']?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final host = read('HOST'), name = read('NAME'), user = read('USER');
    if (host == null || name == null || user == null) return null;
    return TestDatabase._(
      DatabaseConfig(
        host: host,
        port: int.parse(read('PORT') ?? '3306'),
        name: name,
        user: user,
        password: env['JITAN_TEST_DB_PASSWORD'] ?? '',
        secure: (read('SECURE') ?? 'true') == 'true',
      ),
    );
  }
}
