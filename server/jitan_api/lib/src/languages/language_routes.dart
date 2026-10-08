import 'package:jitan_models/jitan_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/request_identity.dart';
import '../http/api_exception.dart';
import '../http/json_request.dart';
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
  /// - `PUT /me/language` `{languageCode}`: change it (audited). Consumer:
  ///   the employee app's language setting, whose Profile screen is not
  ///   designed yet (PRODUCT_CLARIFICATIONS, EMP-06).
  ///
  /// Any signed-in user may read and change their own language, so this
  /// needs an identity but no permission.
  Router get authenticatedRouter => Router()
    ..get('/me/language', _userLanguage)
    ..put('/me/language', _setUserLanguage);

  Future<Response> _list(Request request) async =>
      jsonResponse(LanguageListResponse(languages: await _languages.listLanguages()).toJson());

  Future<Response> _bundle(Request request) async => jsonResponse(
        (await _languages.translationBundle(request.url.queryParameters['language'])).toJson(),
      );

  Future<Response> _setUserLanguage(Request request) async {
    final identity = request.identity;
    final SetUserLanguageRequest body;
    try {
      body = SetUserLanguageRequest.fromJson(await readJsonObject(request));
    } on FormatException catch (e) {
      throw ApiException.badRequest(e.message);
    }
    final code = await _languages.setUserLanguage(identity.userId, body);
    return jsonResponse(UserLanguageResponse(languageCode: code).toJson());
  }

  Future<Response> _userLanguage(Request request) async {
    final identity = request.identity;
    final code = await _languages.userLanguageCode(identity.userId);
    return jsonResponse(UserLanguageResponse(languageCode: code).toJson());
  }
}
