import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/app_environment.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:test/test.dart';

const _db = {
  'JITAN_DB_HOST': 'db.local',
  'JITAN_DB_NAME': 'jitan',
  'JITAN_DB_USER': 'jitan_app',
  'JITAN_DB_PASSWORD': 's3cret',
};

void main() {
  group('environment', () {
    test('defaults to production when JITAN_ENV is unset', () {
      final config = AppConfig.fromEnvironment(_db);
      expect(config.environment, AppEnvironment.production);
    });

    test('rejects an unknown JITAN_ENV', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'staging'}),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('development identity guard', () {
    test('production refuses to start when JITAN_DEV_USER_ID is set', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'production', 'JITAN_DEV_USER_ID': '1'}),
        throwsA(isA<ConfigException>()
            .having((e) => e.message, 'message', contains('JITAN_DEV_USER_ID'))),
      );
    });

    test('unset JITAN_ENV with a dev variable also refuses (defaults to production)', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_DEV_USER_ID': '1'}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('production refuses any other JITAN_DEV_* variable too', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_DEV_ANYTHING': 'x'}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('production ignores an empty JITAN_DEV_* variable', () {
      final config = AppConfig.fromEnvironment({..._db, 'JITAN_DEV_USER_ID': ''});
      expect(config.devUserId, isNull);
    });

    test('development reads JITAN_DEV_USER_ID', () {
      final config =
          AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'development', 'JITAN_DEV_USER_ID': '42'});
      expect(config.devUserId, 42);
    });

    test('development rejects a non-numeric JITAN_DEV_USER_ID', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'development', 'JITAN_DEV_USER_ID': 'SBW'}),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('database and http', () {
    test('requires the database host, name and user', () {
      for (final key in ['JITAN_DB_HOST', 'JITAN_DB_NAME', 'JITAN_DB_USER']) {
        final env = Map.of(_db)..remove(key);
        expect(() => AppConfig.fromEnvironment(env), throwsA(isA<ConfigException>()), reason: key);
      }
    });

    test('applies defaults', () {
      final config = AppConfig.fromEnvironment(_db);
      expect(config.httpHost, '127.0.0.1');
      expect(config.httpPort, 8080);
      expect(config.database.port, 3306);
      expect(config.database.secure, isTrue);
      expect(config.corsOrigins, isEmpty);
    });

    test('parses CORS origins', () {
      final config = AppConfig.fromEnvironment(
        {..._db, 'JITAN_CORS_ORIGINS': 'http://localhost:5000, http://127.0.0.1:5000,'},
      );
      expect(config.corsOrigins, {'http://localhost:5000', 'http://127.0.0.1:5000'});
    });

    test('rejects an invalid port', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_HTTP_PORT': '99999'}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('database description never contains the password', () {
      final config = AppConfig.fromEnvironment(_db);
      expect(config.database.toString(), isNot(contains('s3cret')));
    });
  });
}
