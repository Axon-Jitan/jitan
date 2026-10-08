import 'package:jitan_models/jitan_models.dart';

import '../http/api_exception.dart';
import 'language_repository.dart';
import 'user_language_service.dart';
import 'translation_repository.dart';

/// Languages and database-driven UI translations (I18N-01).
///
/// The server only serves what is in the database. The fallback chain
/// (selected language → English → key) is applied by the client
/// translation service.
class LanguageService {
  const LanguageService(this._languages, this._translations, this._languageChanges);

  final LanguageRepository _languages;
  final TranslationRepository _translations;
  final UserLanguageService _languageChanges;

  static const maxLanguageCodeLength = 16;

  Future<List<Language>> listLanguages() => _languages.listActiveLanguages();

  /// All texts of the active language [code]. 404 for an unknown or inactive
  /// language, so a typo in a language code is never silently served as empty.
  Future<TranslationBundle> translationBundle(String? code) async {
    final trimmed = code?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw const ApiException.badRequest('Query parameter "language" is required.');
    }
    if (trimmed.length > maxLanguageCodeLength) {
      throw const ApiException.badRequest(
        'Language code must be at most $maxLanguageCodeLength characters.',
      );
    }
    final language = await _languages.findActiveByCode(trimmed);
    if (language == null) {
      throw ApiException.notFound('No active language with code "$trimmed".');
    }
    return TranslationBundle(
      languageCode: language.code,
      texts: await _translations.textsForLanguage(language.id),
    );
  }

  /// The signed-in user changes their own preferred language, any time.
  /// Returns the language now in effect.
  Future<String> setUserLanguage(int userId, SetUserLanguageRequest request) async {
    final code = request.languageCode.trim();
    final language = code.isEmpty || code.length > maxLanguageCodeLength ? null : await _languages.findActiveByCode(code);
    if (language == null) {
      throw const ApiException.validation(SetUserLanguageRequest.fieldLanguageCode, 'Choose an active language.');
    }
    await _languageChanges.change(actorUserId: userId, userId: userId, languageId: language.id);
    return language.code;
  }

  /// The user's language from `tblUserLanguage`.
  ///
  /// - none assigned → `null` (the client then uses English, the default)
  /// - one → its code
  /// - several → 409 `configuration_error`: which one applies is not defined
  ///   (CLARIFY-07), and the server does not pick one silently.
  Future<String?> userLanguageCode(int userId) async {
    final codes = await _languages.activeLanguageCodesForUser(userId);
    if (codes.length > 1) {
      throw ApiException.configurationError(
        'User $userId has several languages assigned (${codes.join(', ')}); expected at most one.',
      );
    }
    return codes.isEmpty ? null : codes.single;
  }
}
