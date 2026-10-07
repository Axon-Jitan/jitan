import 'package:jitan_models/jitan_models.dart';
import 'package:test/test.dart';

void main() {
  test('LanguageListResponse round-trips', () {
    const original = LanguageListResponse(
      languages: [
        Language(id: 1, code: 'en', name: 'English'),
        Language(id: 2, code: 'nl', name: 'Dutch'),
      ],
    );

    final decoded = LanguageListResponse.fromJson(original.toJson());

    expect(decoded.languages.map((l) => l.code), ['en', 'nl']);
    expect(decoded.languages.last.name, 'Dutch');
  });

  test('TranslationBundle round-trips', () {
    const original = TranslationBundle(languageCode: 'nl', texts: {'common.save': 'Opslaan'});

    final decoded = TranslationBundle.fromJson(original.toJson());

    expect(decoded.languageCode, 'nl');
    expect(decoded.texts, {'common.save': 'Opslaan'});
  });

  test('TranslationBundle rejects a non-string text', () {
    expect(
      () => TranslationBundle.fromJson({
        'language': 'nl',
        'translations': {'common.save': 3},
      }),
      throwsFormatException,
    );
  });

  test('UserLanguageResponse accepts a code or null', () {
    expect(UserLanguageResponse.fromJson({'languageCode': 'fr'}).languageCode, 'fr');
    expect(UserLanguageResponse.fromJson({'languageCode': null}).languageCode, isNull);
    expect(() => UserLanguageResponse.fromJson({'languageCode': 1}), throwsFormatException);
  });
}
