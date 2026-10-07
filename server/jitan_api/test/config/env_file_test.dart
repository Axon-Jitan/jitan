import 'package:jitan_api/src/config/env_file.dart';
import 'package:test/test.dart';

void main() {
  test('parses keys, comments, blanks, export and quotes', () {
    final values = parseEnvFile([
      '# comment',
      '',
      'JITAN_ENV=development',
      'export JITAN_DB_HOST = db.local ',
      'JITAN_DB_PASSWORD="p=ss word"',
      "JITAN_CORS_ORIGINS='http://localhost:5000'",
      'JITAN_DEV_USER_ID=',
    ]);

    expect(values, {
      'JITAN_ENV': 'development',
      'JITAN_DB_HOST': 'db.local',
      'JITAN_DB_PASSWORD': 'p=ss word',
      'JITAN_CORS_ORIGINS': 'http://localhost:5000',
      'JITAN_DEV_USER_ID': '',
    });
  });

  test('rejects a line without "="', () {
    expect(() => parseEnvFile(['JITAN_ENV development']), throwsFormatException);
  });
}
