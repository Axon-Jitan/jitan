import 'package:jitan_api_client/jitan_api_client.dart';
import 'package:jitan_models/jitan_models.dart';

/// Serves translation bundles and the user language from memory.
class FakeLanguagesApi implements LanguagesApi {
  FakeLanguagesApi(this.bundles, {this.userLanguage});

  Map<String, Map<String, String>> bundles;
  String? userLanguage;

  /// When set, the next call fails with it (then clears).
  ApiClientException? failNext;
  final requests = <String>[];

  @override
  Future<TranslationBundle> translationBundle(String languageCode) async {
    requests.add('translations:$languageCode');
    _maybeFail();
    final texts = bundles[languageCode];
    if (texts == null) {
      throw const ApiClientException.server(404, ApiError(code: ApiErrorCode.notFound, message: 'x'));
    }
    return TranslationBundle(languageCode: languageCode, texts: texts);
  }

  @override
  Future<String?> currentUserLanguage() async {
    requests.add('me/language');
    _maybeFail();
    return userLanguage;
  }

  @override
  Future<List<Language>> listLanguages() async => const [];

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }
}
