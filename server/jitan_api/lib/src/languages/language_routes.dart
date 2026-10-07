import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/request_identity.dart';
import '../http/json_response.dart';
import 'language_service.dart';

/// Language and translation endpoints. Consumer: the shared client
/// translation service (`packages/jitan_core`), used by every app.
class LanguageRoutes {
  const LanguageRoutes(this._languages);

  final LanguageService _languages;

  /// No sign-in needed: the login screen must be translated too, and the
  /// content is UI text only.
  ///
  /// - `GET /languages`
  /// - `GET /translations?language=<code>`
  Router get publicRouter => Router()
    ..get('/languages', _list)
    ..get('/translations', _bundle);

  /// - `GET /me/language`: the signed-in user's language.
  ///
  /// Any signed-in user may read their own language, so this needs an
  /// identity but no permission.
  Router get authenticatedRouter => Router()..get('/me/language', _userLanguage);

  Future<Response> _list(Request request) async =>
      jsonResponse(LanguageListResponse(languages: await _languages.listLanguages()).toJson());

  Future<Response> _bundle(Request request) async => jsonResponse(
        (await _languages.translationBundle(request.url.queryParameters['language'])).toJson(),
      );

  Future<Response> _userLanguage(Request request) async {
    final identity = request.identity;
    final code = await _languages.userLanguageCode(identity.userId);
    return jsonResponse(UserLanguageResponse(languageCode: code).toJson());
  }
}
