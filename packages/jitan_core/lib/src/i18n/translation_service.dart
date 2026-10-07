import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import 'translations.dart';

final _log = Logger('i18n');

/// Resolves the user's language and loads its database bundle.
///
/// **Never a precondition for rendering.** Apps start with
/// [cachedForCurrentUser] when the user's language is already cached, else
/// [Translations.english], which needs nothing, and swap in the result of
/// [loadForCurrentUser] or [load] when it arrives. Every failure here ends in
/// English, logged, and never in an error screen or a blank label.
///
/// Bundles are fetched whole and cached in memory per language for the
/// session. A cached bundle keeps working when the API later becomes
/// unreachable.
class TranslationService {
  TranslationService(this._api);

  final LanguagesApi _api;
  final _cache = <String, Map<String, String>>{};

  /// The user's language as last confirmed by the server this session.
  String? _lastUserLanguage;

  /// Translations for the signed-in user's language (`tblUserLanguage`), or
  /// English when there is none, the user is not signed in, or anything fails
  /// and no cached user language is available.
  Future<Translations> loadForCurrentUser() async => load(await resolveUserLanguageCode());

  /// The user's language straight from the in-memory cache, with no request:
  /// lets an app render its first frame in the user's language when it is
  /// already known. `null` when the user language or its bundle is not cached.
  Translations? cachedForCurrentUser() {
    final code = _lastUserLanguage;
    if (code == null) return null;
    if (code == englishLanguageCode) return Translations.english();
    final cached = _cache[code];
    return cached == null ? null : Translations(languageCode: code, selected: cached);
  }

  /// Translations for [languageCode].
  ///
  /// - English: built-in, no request.
  /// - Cached: no request.
  /// - Otherwise fetched; on any failure (offline, API/database down,
  ///   unknown language) English is returned and the reason logged.
  Future<Translations> load(String languageCode) async {
    if (languageCode == englishLanguageCode) return Translations.english();

    final cached = _cache[languageCode];
    if (cached != null) return Translations(languageCode: languageCode, selected: cached);

    try {
      final bundle = await _api.translationBundle(languageCode);
      _cache[languageCode] = bundle.texts;
      return Translations(languageCode: languageCode, selected: bundle.texts);
    } on ApiClientException catch (e) {
      _log.warning('Could not load "$languageCode" translations ($e); using built-in English.');
      return Translations.english();
    }
  }

  /// The user's language code:
  /// - from the server (`tblUserLanguage`); none assigned → English
  /// - not signed in (401) → English, and the remembered language is forgotten
  /// - several assigned (409 `configuration_error`, CLARIFY-07) → English, logged as an error
  /// - API/database unreachable → the user language remembered this session
  ///   if its bundle is cached, otherwise English; logged
  Future<String> resolveUserLanguageCode() async {
    try {
      final code = await _api.currentUserLanguage() ?? englishLanguageCode;
      _lastUserLanguage = code;
      return code;
    } on ApiClientException catch (e) {
      switch (e.error?.code) {
        case ApiErrorCode.unauthenticated:
          _lastUserLanguage = null;
          return englishLanguageCode;
        case ApiErrorCode.configurationError:
          _log.severe('User language is misconfigured (${e.error?.message}); using English.');
          return englishLanguageCode;
        default:
          final cached = cachedForCurrentUser();
          _log.warning(
            'Could not read the user language ($e); '
            'using ${cached == null ? 'English' : 'cached "${cached.languageCode}"'}.',
          );
          return cached?.languageCode ?? englishLanguageCode;
      }
    }
  }

  /// Drops cached bundles and the remembered user language, e.g. after
  /// signing in as another user.
  void clearCache() {
    _cache.clear();
    _lastUserLanguage = null;
  }
}
