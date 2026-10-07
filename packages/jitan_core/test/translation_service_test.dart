import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// Serves bundles from memory and counts requests.
class FakeLanguagesApi implements LanguagesApi {
  FakeLanguagesApi(this.bundles, {this.userLanguage});

  final Map<String, Map<String, String>> bundles;
  Object? userLanguage; // String, null, or an ApiClientException to throw
  final requests = <String>[];
  Object? failNextBundleWith;

  @override
  Future<TranslationBundle> translationBundle(String languageCode) async {
    requests.add(languageCode);
    final failure = failNextBundleWith;
    if (failure != null) {
      failNextBundleWith = null;
      throw failure;
    }
    final texts = bundles[languageCode];
    if (texts == null) {
      throw const ApiClientException.server(404, ApiError(code: ApiErrorCode.notFound, message: 'x'));
    }
    return TranslationBundle(languageCode: languageCode, texts: texts);
  }

  @override
  Future<String?> currentUserLanguage() async {
    final value = userLanguage;
    if (value is ApiClientException) throw value;
    return value as String?;
  }

  @override
  Future<List<Language>> listLanguages() async => const [];
}

void main() {
  final logs = <LogRecord>[];
  setUpAll(() => Logger.root.onRecord.listen(logs.add));
  setUp(logs.clear);

  final english = {'company.add': 'Add company', 'common.save': 'Save', 'common.days.one': '{n} day', 'common.days.other': '{n} days'};
  final dutch = {'company.add': 'Bedrijf toevoegen'};

  group('fallback chain', () {
    test('selected language first', () async {
      final t = await TranslationService(FakeLanguagesApi({'en': english, 'nl': dutch})).load('nl');

      expect(t.t('company.add'), 'Bedrijf toevoegen');
      expect(t.languageCode, 'nl');
    });

    test('falls back to English when the selected language lacks the key', () async {
      final t = await TranslationService(FakeLanguagesApi({'en': english, 'nl': dutch})).load('nl');

      expect(t.t('common.save'), 'Save');
    });

    test('shows the key itself when English lacks it too, and logs it once', () async {
      final t = await TranslationService(FakeLanguagesApi({'en': english, 'nl': dutch})).load('nl');

      expect(t.t('company.delete'), 'company.delete');
      expect(t.t('company.delete'), 'company.delete');
      expect(logs.where((r) => r.message.contains('"company.delete"')), hasLength(1));
    });
  });

  group('loading and caching', () {
    test('loads English once and the selected bundle once', () async {
      final api = FakeLanguagesApi({'en': english, 'nl': dutch});
      final service = TranslationService(api);

      await service.load('nl');
      await service.load('nl');

      expect(api.requests, ['en', 'nl']);
    });

    test('English selected needs a single request', () async {
      final api = FakeLanguagesApi({'en': english});

      await TranslationService(api).load('en');

      expect(api.requests, ['en']);
    });

    test('switching language reuses the cached English bundle', () async {
      final api = FakeLanguagesApi({'en': english, 'nl': dutch, 'fr': {'company.add': 'Ajouter une entreprise'}});
      final service = TranslationService(api);

      final nl = await service.load('nl');
      final fr = await service.load('fr');

      expect(nl.t('company.add'), 'Bedrijf toevoegen');
      expect(fr.t('company.add'), 'Ajouter une entreprise');
      expect(fr.t('common.save'), 'Save');
      expect(api.requests, ['en', 'nl', 'fr']);
    });

    test('an unavailable selected language shows English and is logged', () async {
      final t = await TranslationService(FakeLanguagesApi({'en': english})).load('de');

      expect(t.languageCode, 'en');
      expect(t.t('company.add'), 'Add company');
      expect(logs.any((r) => r.message.contains('"de" is not available')), isTrue);
    });

    test('failing to load English is an error, not an empty UI', () async {
      final api = FakeLanguagesApi({})..failNextBundleWith = const ApiClientException.network('offline');

      expect(TranslationService(api).load('en'), throwsA(isA<ApiClientException>()));
    });

    test('a failed load is not cached, so retry works', () async {
      final api = FakeLanguagesApi({'en': english})..failNextBundleWith = const ApiClientException.network('offline');
      final service = TranslationService(api);

      await expectLater(service.load('en'), throwsA(isA<ApiClientException>()));
      final t = await service.load('en');

      expect(t.t('common.save'), 'Save');
    });
  });

  group('user language', () {
    test('uses the user language from the server', () async {
      final api = FakeLanguagesApi({}, userLanguage: 'nl');
      expect(await TranslationService(api).resolveUserLanguageCode(), 'nl');
    });

    test('defaults to English when the user has none', () async {
      final api = FakeLanguagesApi({});
      expect(await TranslationService(api).resolveUserLanguageCode(), 'en');
    });

    test('uses English and logs when several languages are assigned', () async {
      final api = FakeLanguagesApi({}, userLanguage: const ApiClientException.server(
        409,
        ApiError(code: ApiErrorCode.configurationError, message: 'several'),
      ));

      expect(await TranslationService(api).resolveUserLanguageCode(), 'en');
      expect(logs.any((r) => r.level == Level.SEVERE), isTrue);
    });

    test('uses English before sign-in (401)', () async {
      final api = FakeLanguagesApi({}, userLanguage: const ApiClientException.server(
        401,
        ApiError(code: ApiErrorCode.unauthenticated, message: 'x'),
      ));

      expect(await TranslationService(api).resolveUserLanguageCode(), 'en');
    });

    test('other failures propagate', () async {
      final api = FakeLanguagesApi({}, userLanguage: const ApiClientException.network('offline'));
      expect(TranslationService(api).resolveUserLanguageCode(), throwsA(isA<ApiClientException>()));
    });
  });

  group('Translations', () {
    test('substitutes arguments and plurals', () {
      final t = Translations(languageCode: 'en', selected: english, fallback: english);

      expect(t.plural('common.days', 1), '1 day');
      expect(t.plural('common.days', 3), '3 days');
      expect(t.t('x.{name}', args: {'name': 'y'}), 'x.y', reason: 'missing key still substitutes');
    });

    test('keysOnly shows every key', () {
      expect(Translations.keysOnly().t('company.add'), 'company.add');
    });
  });
}
