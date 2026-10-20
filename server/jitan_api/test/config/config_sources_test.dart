import 'dart:io';

import 'package:jitan_api/src/config/config_exception.dart';
import 'package:jitan_api/src/config/config_sources.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  String file(String name, String content) {
    final path = '${dir.path}/$name';
    File(path).writeAsStringSync(content);
    return path;
  }

  setUp(() => dir = Directory.systemTemp.createTempSync('jitan_config_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('environment overrides the configuration file, which overrides the development .env', () {
    final sources = ConfigSources.load(
      {'PORT': '9000'},
      defaultFile: file('app.env', 'PORT=8080\nDB_NAME=jitandev\n'),
      developmentFile: file('.env', 'PORT=7000\nDB_NAME=local\nJITAN_ENV=development\n'),
    );

    expect(sources.value(['PORT']), '9000');
    expect(sources.value(['DB_NAME']), 'jitandev');
    expect(sources.value(['JITAN_ENV']), 'development');
  });

  test('a missing default file is fine (development machine)', () {
    final sources = ConfigSources.load(
      const {},
      defaultFile: '${dir.path}/absent.env',
      developmentFile: '${dir.path}/absent.env',
    );
    expect(sources.value(['PORT']), isNull);
  });

  test('JITAN_CONFIG_FILE selects the file, and it must exist', () {
    final chosen = file('chosen.env', 'PORT=8443\n');
    final sources = ConfigSources.load(
      {'JITAN_CONFIG_FILE': chosen},
      defaultFile: file('app.env', 'PORT=8080\n'),
      developmentFile: '${dir.path}/absent.env',
    );
    expect(sources.value(['PORT']), '8443');

    expect(
      () => ConfigSources.load({'JITAN_CONFIG_FILE': '${dir.path}/missing.env'}),
      throwsA(isA<ConfigException>()),
    );
    expect(() => ConfigSources.load({'JITAN_CONFIG_FILE': ' '}), throwsA(isA<ConfigException>()));
  });

  test('an invalid file refuses to start, and the message never shows the line', () {
    expect(
      () => ConfigSources.load(
        const {},
        defaultFile: file('app.env', 'DB_PASS=secret-one\nDB_PASS=secret-two\n'),
        developmentFile: '${dir.path}/absent.env',
      ),
      throwsA(isA<ConfigException>().having((e) => e.message, 'message', allOf(contains('line 2'), isNot(contains('secret'))))),
    );
  });

  test('every name is looked for in the higher source before the lower one', () {
    const sources = ConfigSources([
      {'JITAN_HTTP_HOST': '0.0.0.0'},
      {'BIND_ADDRESS': '10.1.101.65'},
    ]);
    expect(sources.value(['BIND_ADDRESS', 'HOST', 'JITAN_HTTP_HOST']), '0.0.0.0');
  });

  test('a blank value counts as unset and is not filled from a lower source', () {
    const sources = ConfigSources([
      {'PORT': ' '},
      {'PORT': '8080'},
    ]);
    expect(sources.value(['PORT']), isNull);
    expect(sources.keysWithValues, {'PORT'});
  });

  test('untrimmed keeps spaces (passwords)', () {
    const sources = ConfigSources([
      {'DB_PASS': ' p w '},
    ]);
    expect(sources.untrimmed(['DB_PASS']), ' p w ');
    expect(sources.value(['DB_PASS']), 'p w');
  });
}
