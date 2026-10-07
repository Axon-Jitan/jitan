import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import 'translations.dart';

final _log = Logger('i18n');

/// Resolves the user's language and loads its database bundle.
///
/// **Never a precondition for rendering.** Apps start with
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

  /// Translations for the signed-in user's language (`tblUserLanguage`), or
  /// English when there is none, the user is not signed in, or anything fails.
  Future<Translations> loadForCurrentUser() async => load(await resolveUserLanguageCode());

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

  /// The user's language code, or English:
  /// - none assigned, or not signed in (401) → English
  /// - several assigned (409 `configuration_error`, CLARIFY-07) → English, logged as an error
  /// - API/database unreachable → English, logged
  Future<String> resolveUserLanguageCode() async {
    try {
      return await _api.currentUserLanguage() ?? englishLanguageCode;
    } on ApiClientException catch (e) {
      final code = e.error?.code;
      if (code == ApiErrorCode.configurationError) {
        _log.severe('User language is misconfigured (${e.error?.message}); using English.');
      } else if (code != ApiErrorCode.unauthenticated) {
        _log.warning('Could not read the user language ($e); using English.');
      }
      return englishLanguageCode;
    }
  }

  /// Drops cached bundles, e.g. after signing in as another user.
  void clearCache() => _cache.clear();
}
