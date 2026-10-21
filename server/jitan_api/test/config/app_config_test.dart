import 'package:jitan_api/src/config/app_config.dart';
import 'package:jitan_api/src/config/app_environment.dart';
import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/config_sources.dart';
import 'package:test/test.dart';

const _db = {
  'JITAN_DB_HOST': 'db.local',
  'JITAN_DB_NAME': 'jitan',
  'JITAN_DB_USER': 'jitan_app',
  'JITAN_DB_PASSWORD': 's3cret',
  'JITAN_SESSION_SECRET': 'a-production-session-secret-of-32-chars-plus',
  'JITAN_DB_TLS_FINGERPRINTS': _fingerprint,
};

const _fingerprint = '70:26:23:E5:D0:AE:AA:B2:9B:51:AA:5B:C2:85:51:FF:FD:C3:8A:BD:E1:04:32:0F:4F:6B:D2:BE:08:E3:85:B9';

void main() {
  group('environment', () {
    test('defaults to production when JITAN_ENV is unset', () {
      final config = AppConfig.fromEnvironment(_db);
      expect(config.environment, AppEnvironment.production);
    });

    test('rejects an unknown JITAN_ENV', () {
      expect(() => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'staging'}), throwsA(isA<ConfigException>()));
    });
  });

  group('development identity guard', () {
    test('production refuses to start when JITAN_DEV_USER_ID is set', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'production', 'JITAN_DEV_USER_ID': '1'}),
        throwsA(isA<ConfigException>().having((e) => e.message, 'message', contains('JITAN_DEV_USER_ID'))),
      );
    });

    test('unset JITAN_ENV with a dev variable also refuses (defaults to production)', () {
      expect(() => AppConfig.fromEnvironment({..._db, 'JITAN_DEV_USER_ID': '1'}), throwsA(isA<ConfigException>()));
    });

    test('the proposed group schedules (GAP-15): development only, off by default, true/false', () {
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'production', 'JITAN_DEV_GROUP_SCHEDULES': 'true'}),
        throwsA(isA<ConfigException>().having((e) => e.message, 'message', contains('JITAN_DEV_GROUP_SCHEDULES'))),
      );
      expect(AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'development'}).devGroupSchedules, isFalse);
      expect(
        AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'development', 'JITAN_DEV_GROUP_SCHEDULES': 'true'}).devGroupSchedules,
        isTrue,
      );
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'development', 'JITAN_DEV_GROUP_SCHEDULES': 'yes'}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('production refuses any other JITAN_DEV_* variable too', () {
      expect(() => AppConfig.fromEnvironment({..._db, 'JITAN_DEV_ANYTHING': 'x'}), throwsA(isA<ConfigException>()));
    });

    test('production ignores an empty JITAN_DEV_* variable', () {
      final config = AppConfig.fromEnvironment({..._db, 'JITAN_DEV_USER_ID': ''});
      expect(config.devUserId, isNull);
    });

    test('development reads JITAN_DEV_USER_ID', () {
      final config = AppConfig.fromEnvironment({..._db, 'JITAN_ENV': 'development', 'JITAN_DEV_USER_ID': '42'});
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
      expect([for (final a in config.listener.addresses) a.address], ['127.0.0.1']);
      expect(config.listener.port, 8080);
      expect(config.listener.https, isFalse);
      expect(config.database.port, 3306);
      expect(config.database.secure, isTrue);
      expect(config.corsOrigins, isEmpty);
    });

    test('parses CORS origins', () {
      final config = AppConfig.fromEnvironment({
        ..._db,
        'JITAN_CORS_ORIGINS': 'http://localhost:5000, http://127.0.0.1:5000,',
      });
      expect(config.corsOrigins, {'http://localhost:5000', 'http://127.0.0.1:5000'});
    });

    test('rejects an invalid port', () {
      expect(() => AppConfig.fromEnvironment({..._db, 'JITAN_HTTP_PORT': '99999'}), throwsA(isA<ConfigException>()));
    });

    test('database description never contains the password', () {
      final config = AppConfig.fromEnvironment(_db);
      expect(config.database.toString(), isNot(contains('s3cret')));
    });
  });

  group('sessions and password hashing', () {
    test('production requires a session secret of at least 32 characters', () {
      final withoutSecret = Map.of(_db)..remove('JITAN_SESSION_SECRET');
      expect(() => AppConfig.fromEnvironment(withoutSecret), throwsA(isA<ConfigException>()));
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_SESSION_SECRET': 'too-short'}),
        throwsA(isA<ConfigException>()),
      );
    });

    test('development may omit the secret (a random one is used)', () {
      final withoutSecret = Map.of(_db)..remove('JITAN_SESSION_SECRET');
      final config = AppConfig.fromEnvironment({...withoutSecret, 'JITAN_ENV': 'development'});
      expect(config.sessionSecret, isNull);
    });

    test('defaults: 30-day sessions, OWASP Argon2id parameters', () {
      final config = AppConfig.fromEnvironment(_db);
      expect(config.sessionLifetime, const Duration(days: 30));
      expect(config.passwordHashing.memoryKiB, 19456);
      expect(config.passwordHashing.iterations, 2);
    });

    test('Argon2id parameters are configurable but bounded', () {
      final tuned = AppConfig.fromEnvironment({
        ..._db,
        'JITAN_ARGON2_MEMORY_KIB': '47104',
        'JITAN_ARGON2_ITERATIONS': '1',
      });
      expect(tuned.passwordHashing.memoryKiB, 47104);
      expect(
        () => AppConfig.fromEnvironment({..._db, 'JITAN_ARGON2_MEMORY_KIB': '1024'}),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group("IT's configuration names (docs/DEPLOYMENT_CONFIGURATION.md)", () {
    const it = {
      'DB_HOST': 'it-db',
      'DB_PORT': '3307',
      'DB_USER': 'it_user',
      'DB_PASS': ' it pass ',
      'DB_NAME': 'jitandev',
      'JITAN_SESSION_SECRET': 'a-production-session-secret-of-32-chars-plus',
      'JITAN_DB_TLS_FINGERPRINTS': _fingerprint,
    };

    test('DB_* names are read; the password is kept exactly as written', () {
      final db = AppConfig.fromEnvironment(it).database;
      expect((db.host, db.port, db.user, db.password, db.name), ('it-db', 3307, 'it_user', ' it pass ', 'jitandev'));
    });

    test("within one source, IT's name wins over the legacy JITAN_DB_* name", () {
      final db = AppConfig.fromEnvironment({...it, 'JITAN_DB_HOST': 'legacy'}).database;
      expect(db.host, 'it-db');
    });

    test('a legacy name in the environment still overrides the file', () {
      final config = AppConfig.fromSources(ConfigSources([
        {'JITAN_DB_HOST': 'from-environment'},
        it,
      ]));
      expect(config.database.host, 'from-environment');
    });

    test('BIND_ADDRESS, then HOST, then JITAN_HTTP_HOST; PORT, then JITAN_HTTP_PORT', () {
      final config = AppConfig.fromEnvironment({
        ...it,
        'BIND_ADDRESS': '10.1.101.65',
        'HOST': '10.9.9.9',
        'JITAN_HTTP_HOST': '0.0.0.0',
        'PORT': '8443',
        'JITAN_HTTP_PORT': '9000',
      });
      expect([for (final a in config.listener.addresses) a.address], ['10.1.101.65', '127.0.0.1']);
      expect(config.listener.port, 8443);
    });

    test('TLS_CERT and TLS_KEY turn on HTTPS; one alone refuses to start', () {
      final config = AppConfig.fromEnvironment({...it, 'TLS_CERT': '/etc/jitan/tls/a.crt', 'TLS_KEY': '/etc/jitan/tls/a.key'});
      expect(config.listener.https, isTrue);
      expect(() => AppConfig.fromEnvironment({...it, 'TLS_CERT': '/etc/jitan/tls/a.crt'}), throwsA(isA<ConfigException>()));
    });

    test('a JITAN_DEV_* setting in the configuration file is refused in production too', () {
      expect(
        () => AppConfig.fromSources(ConfigSources([
          const {},
          {...it, 'JITAN_DEV_USER_ID': '1'},
        ])),
        throwsA(isA<ConfigException>().having((e) => e.message, 'message', contains('JITAN_DEV_USER_ID'))),
      );
    });

    test('error messages never contain the database password', () {
      try {
        AppConfig.fromEnvironment({...it, 'DB_PORT': 'not-a-port'});
        fail('expected a ConfigException');
      } on ConfigException catch (e) {
        expect(e.message, isNot(contains('it pass')));
      }
    });
  });

  group('database TLS (SEC-01)', () {
    final withoutTls = Map.of(_db)..remove('JITAN_DB_TLS_FINGERPRINTS');

    test('production refuses an unverified database certificate', () {
      expect(
        () => AppConfig.fromEnvironment(withoutTls),
        throwsA(isA<ConfigException>().having((e) => e.message, 'message', contains('JITAN_DB_TLS_FINGERPRINTS'))),
      );
    });

    test('production refuses an unencrypted database connection', () {
      expect(() => AppConfig.fromEnvironment({...withoutTls, 'JITAN_DB_SECURE': 'false'}), throwsA(isA<ConfigException>()));
    });

    test('fingerprints are accepted with colons and any case, and stored as 64 lowercase hex digits', () {
      final db = AppConfig.fromEnvironment(_db).database;
      expect(db.tlsFingerprints, {'702623e5d0aeaab29b51aa5bc28551fffdc38abde104320f4f6bd2be08e385b9'});
      expect(db.verifiesCertificate, isTrue);
    });

    test('several fingerprints, separated by commas (CA and server certificate)', () {
      final db = AppConfig.fromEnvironment({
        ...withoutTls,
        'JITAN_DB_TLS_FINGERPRINTS': '$_fingerprint, ${'AB' * 32},',
      }).database;
      expect(db.tlsFingerprints, hasLength(2));
    });

    test('a CA file is the other way to verify', () {
      final db = AppConfig.fromEnvironment({...withoutTls, 'JITAN_DB_TLS_CA_FILE': '/etc/jitan/tls/db-ca.pem'}).database;
      expect(db.tlsCaFile, '/etc/jitan/tls/db-ca.pem');
      expect(db.verifiesCertificate, isTrue);
    });

    test('both at once, a malformed fingerprint, or TLS settings without TLS are refused', () {
      for (final env in [
        {..._db, 'JITAN_DB_TLS_CA_FILE': '/etc/jitan/tls/db-ca.pem'},
        {...withoutTls, 'JITAN_DB_TLS_FINGERPRINTS': '70:26:23'},
        {..._db, 'JITAN_ENV': 'development', 'JITAN_DB_SECURE': 'false'},
      ]) {
        expect(() => AppConfig.fromEnvironment(env), throwsA(isA<ConfigException>()), reason: '$env');
      }
    });

    test('development may connect without verification, or without TLS', () {
      expect(AppConfig.fromEnvironment({...withoutTls, 'JITAN_ENV': 'development'}).database.verifiesCertificate, isFalse);
      expect(
        AppConfig.fromEnvironment({...withoutTls, 'JITAN_ENV': 'development', 'JITAN_DB_SECURE': 'false'}).database.secure,
        isFalse,
      );
    });
  });
}
