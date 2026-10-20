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

  test('skips a byte-order mark', () {
    expect(parseEnvFile(['﻿PORT=8080']), {'PORT': '8080'});
  });

  test('rejects a repeated key, an invalid key and an unclosed quote', () {
    for (final lines in [
      ['PORT=8080', 'PORT=9000'],
      ['DB-HOST=db'],
      ['1PORT=8080'],
      ['DB_PASS="open'],
    ]) {
      expect(() => parseEnvFile(lines), throwsFormatException, reason: '$lines');
    }
  });

  test('error messages name the line, never its content', () {
    expect(
      () => parseEnvFile(['DB_PASS="s3cret']),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('line 1'), isNot(contains('s3cret'))))),
    );
  });
}
