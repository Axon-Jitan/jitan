import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// Serves database bundles from memory and counts requests.
class FakeLanguagesApi implements LanguagesApi {
  FakeLanguagesApi(this.bundles, {this.userLanguage});

  final Map<String, Map<String, String>> bundles;

  /// A code, `null`, or an [ApiClientException] to throw.
  Object? userLanguage;

  /// When set, every bundle request throws it (API/database unreachable).
  ApiClientException? bundleFailure;
  final requests = <String>[];

  @override
  Future<TranslationBundle> translationBundle(String languageCode) async {
    requests.add(languageCode);
    if (bundleFailure != null) throw bundleFailure!;
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

ApiClientException _serverError(int status, String code) =>
    ApiClientException.server(status, ApiError(code: code, message: 'x'));

void main() {
  final logs = <LogRecord>[];
  setUpAll(() => Logger.root.onRecord.listen(logs.add));
  setUp(logs.clear);

  const dutch = {'company.title': 'Bedrijven'};

  group('resolution order', () {
    test('English uses the built-in bundle directly, with no request', () async {
      final api = FakeLanguagesApi({'nl': dutch});

      final t = await TranslationService(api).load('en');

      expect(t.t('company.title'), 'Companies');
      expect(api.requests, isEmpty);
    });

    test('another language uses its database translation first', () async {
      final t = await TranslationService(FakeLanguagesApi({'nl': dutch})).load('nl');

      expect(t.languageCode, 'nl');
      expect(t.t('company.title'), 'Bedrijven');
    });

    test('a translation missing in that language falls back to built-in English', () async {
      final t = await TranslationService(FakeLanguagesApi({'nl': dutch})).load('nl');

      expect(t.t('company.search'), 'Search companies');
    });

    test('a key missing even in built-in English shows the key, logged once', () async {
      final t = await TranslationService(FakeLanguagesApi({'nl': dutch})).load('nl');

      expect(t.t('company.delete.never'), 'company.delete.never');
      expect(t.t('company.delete.never'), 'company.delete.never');
      expect(logs.where((r) => r.message.contains('"company.delete.never"')), hasLength(1));
    });

    test('a database English copy is never needed', () async {
      final api = FakeLanguagesApi({}); // no 'en' bundle in the database at all

      final t = await TranslationService(api).load('en');

      expect(t.t('common.retry'), 'Try again');
    });
  });

  group('API or database unavailable', () {
    for (final (label, failure) in [
      ('offline', const ApiClientException.network('offline')),
      ('database down', _serverError(503, ApiErrorCode.databaseUnavailable)),
      ('unknown language', _serverError(404, ApiErrorCode.notFound)),
      ('broken response', const ApiClientException.invalidResponse(200, 'x')),
    ]) {
      test('$label: built-in English, logged, never an error', () async {
        final api = FakeLanguagesApi({'nl': dutch})..bundleFailure = failure;

        final t = await TranslationService(api).load('nl');

        expect(t.languageCode, 'en');
        expect(t.t('company.title'), 'Companies');
        expect(logs.any((r) => r.message.contains('using built-in English')), isTrue);
      });
    }

    test('a bundle loaded earlier keeps working when the API later goes down', () async {
      final api = FakeLanguagesApi({'nl': dutch});
      final service = TranslationService(api);
      await service.load('nl');

      api.bundleFailure = const ApiClientException.network('offline');
      final t = await service.load('nl');

      expect(t.t('company.title'), 'Bedrijven');
      expect(api.requests, ['nl'], reason: 'served from cache');
    });

    test('a failed load is not cached, so a later load retries', () async {
      final api = FakeLanguagesApi({'nl': dutch})..bundleFailure = const ApiClientException.network('offline');
      final service = TranslationService(api);
      expect((await service.load('nl')).languageCode, 'en');

      api.bundleFailure = null;
      expect((await service.load('nl')).t('company.title'), 'Bedrijven');
    });
  });

  group('language switching', () {
    test('switches between database languages and back to English', () async {
      final api = FakeLanguagesApi({'nl': dutch, 'fr': {'company.title': 'Entreprises'}});
      final service = TranslationService(api);

      expect((await service.load('nl')).t('company.title'), 'Bedrijven');
      expect((await service.load('fr')).t('company.title'), 'Entreprises');
      expect((await service.load('en')).t('company.title'), 'Companies');
      expect((await service.load('nl')).t('company.title'), 'Bedrijven');
      expect(api.requests, ['nl', 'fr'], reason: 'each bundle fetched once');
    });

    test('clearCache forces a fresh fetch', () async {
      final api = FakeLanguagesApi({'nl': dutch});
      final service = TranslationService(api);
      await service.load('nl');

      service.clearCache();
      await service.load('nl');

      expect(api.requests, ['nl', 'nl']);
    });
  });

  group('user language (tblUserLanguage)', () {
    Future<String> resolve(Object? userLanguage) =>
        TranslationService(FakeLanguagesApi({}, userLanguage: userLanguage)).resolveUserLanguageCode();

    test('uses the assigned language', () async => expect(await resolve('nl'), 'nl'));

    test('defaults to English when none is assigned', () async => expect(await resolve(null), 'en'));

    test('English when not signed in', () async {
      expect(await resolve(_serverError(401, ApiErrorCode.unauthenticated)), 'en');
    });

    test('English, logged as an error, when several are assigned', () async {
      expect(await resolve(_serverError(409, ApiErrorCode.configurationError)), 'en');
      expect(logs.any((r) => r.level == Level.SEVERE), isTrue);
    });

    test('English when the API is unreachable', () async {
      expect(await resolve(const ApiClientException.network('offline')), 'en');
    });

    test('loadForCurrentUser combines both steps', () async {
      final api = FakeLanguagesApi({'nl': dutch}, userLanguage: 'nl');

      final t = await TranslationService(api).loadForCurrentUser();

      expect(t.t('company.title'), 'Bedrijven');
    });
  });

  group('Translations', () {
    test('substitutes arguments and picks plural forms', () {
      final t = Translations.english();

      expect(t.plural(CommonTextKeys.dateDaysAgo, 1), '1 day ago');
      expect(t.plural(CommonTextKeys.dateDaysAgo, 3), '3 days ago');
      expect(t.t('company.noMatch.message', args: {'search': 'Zeta'}), 'No company name contains “Zeta”.');
    });

    test('English never applies a database bundle, even if one is passed', () {
      final t = Translations(languageCode: 'en', selected: const {'company.title': 'Other'});

      expect(t.t('company.title'), 'Companies');
    });

    test('built-in English plural keys come in complete pairs', () {
      final bases = builtInEnglish.keys
          .where((k) => k.endsWith('.one') || k.endsWith('.other'))
          .map((k) => k.substring(0, k.lastIndexOf('.')))
          .toSet();
      for (final base in bases) {
        expect(builtInEnglish, contains('$base.one'), reason: base);
        expect(builtInEnglish, contains('$base.other'), reason: base);
      }
    });
  });
}
