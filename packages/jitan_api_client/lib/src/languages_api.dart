import 'package:jitan_models/jitan_models.dart';

import 'api_client_exception.dart';
import 'api_transport.dart';

/// `/languages`, `/translations` and `/me/language` endpoints.
class LanguagesApi {
  const LanguagesApi(this._transport);

  final ApiTransport _transport;

  Future<List<Language>> listLanguages() =>
      _decode('languages', () async => LanguageListResponse.fromJson(await _transport.getJson('languages')).languages);

  /// The full translation bundle of [languageCode].
  Future<TranslationBundle> translationBundle(String languageCode) => _decode(
        'translations',
        () async => TranslationBundle.fromJson(
          await _transport.getJson('translations', query: {'language': languageCode}),
        ),
      );

  /// The signed-in user's language code, or `null` when none is set.
  Future<String?> currentUserLanguage() => _decode(
        'me/language',
        () async => UserLanguageResponse.fromJson(await _transport.getJson('me/language')).languageCode,
      );

  /// Changes the signed-in user's own language; returns the code now in
  /// effect.
  Future<String?> setCurrentUserLanguage(String languageCode) => _decode(
        'me/language',
        () async => UserLanguageResponse.fromJson(
          await _transport.putJson('me/language', SetUserLanguageRequest(languageCode: languageCode).toJson()),
        ).languageCode,
      );

  static Future<T> _decode<T>(String path, Future<T> Function() call) async {
    try {
      return await call();
    } on FormatException catch (e) {
      throw ApiClientException.invalidResponse(200, '$path: ${e.message}');
    }
  }
}
