import 'dart:async';

import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:logging/logging.dart';

import 'translations.dart';

final _log = Logger('i18n');

/// Loads database translation bundles through the API and caches them.
///
/// Bundles are fetched whole, once per language per session. Call [load] on
/// app start, session start and language change; repeat calls for a cached
/// language make no request. [clearCache] forces a reload (e.g. after
/// sign-in as another user).
class TranslationService {
  TranslationService(this._api);

  final LanguagesApi _api;
  final _bundles = <String, Future<Map<String, String>>>{};

  /// Texts for [languageCode] with English as fallback.
  ///
  /// - The English bundle is required: if it cannot be loaded, this throws.
  /// - A selected language the server does not know (inactive or removed,
  ///   404) is shown entirely through the English fallback, and logged.
  Future<Translations> load(String languageCode) async {
    final fallback = await _bundle(fallbackLanguageCode);
    if (languageCode == fallbackLanguageCode) {
      return Translations(languageCode: languageCode, selected: fallback, fallback: fallback);
    }
    try {
      final selected = await _bundle(languageCode);
      return Translations(languageCode: languageCode, selected: selected, fallback: fallback);
    } on ApiClientException catch (e) {
      if (e.error?.code != ApiErrorCode.notFound) rethrow;
      _log.warning('Language "$languageCode" is not available; showing "$fallbackLanguageCode".');
      return Translations(languageCode: fallbackLanguageCode, selected: fallback, fallback: fallback);
    }
  }

  /// The signed-in user's language code from `tblUserLanguage`, or English
  /// when none is set.
  ///
  /// - Not signed in (401): English. Screens before sign-in must still render.
  /// - Several languages assigned (409 `configuration_error`, CLARIFY-07): the
  ///   app still has to render, so English is used and the data problem is
  ///   logged.
  /// - Anything else is rethrown.
  Future<String> resolveUserLanguageCode() async {
    try {
      return await _api.currentUserLanguage() ?? fallbackLanguageCode;
    } on ApiClientException catch (e) {
      switch (e.error?.code) {
        case ApiErrorCode.unauthenticated:
          return fallbackLanguageCode;
        case ApiErrorCode.configurationError:
          _log.severe('User language is misconfigured (${e.error?.message}); showing "$fallbackLanguageCode".');
          return fallbackLanguageCode;
        default:
          rethrow;
      }
    }
  }

  void clearCache() => _bundles.clear();

  Future<Map<String, String>> _bundle(String code) {
    return _bundles.putIfAbsent(code, () async {
      try {
        return (await _api.translationBundle(code)).texts;
      } catch (_) {
        unawaited(_bundles.remove(code)); // do not cache failures; allow retry
        rethrow;
      }
    });
  }
}
