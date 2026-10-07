import 'package:jitan_core/jitan_core.dart';
import 'package:test/test.dart';

void main() {
  test('tOrNull: database text, then English, then null (never the key)', () {
    final dutch = Translations(
      languageCode: 'nl',
      selected: {'a': 'Nederlands A'},
      fallback: {'a': 'English A', 'b': 'English B'},
    );

    expect(dutch.tOrNull('a'), 'Nederlands A');
    expect(dutch.tOrNull('b'), 'English B');
    expect(dutch.tOrNull('missing'), isNull);
  });
}
