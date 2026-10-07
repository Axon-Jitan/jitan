import 'json_reading.dart';

/// An active `tblLanguage` row.
class Language {
  const Language({required this.id, required this.code, required this.name});

  factory Language.fromJson(Map<String, Object?> json) => Language(
        id: json.readInt('id'),
        code: json.readString('code'),
        name: json.readString('name'),
      );

  final int id;

  /// `tblLanguage.languageCode`, e.g. `en`, `nl`, `fr`.
  final String code;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'code': code, 'name': name};
}

/// Response body of `GET /languages`.
class LanguageListResponse {
  const LanguageListResponse({required this.languages});

  factory LanguageListResponse.fromJson(Map<String, Object?> json) => LanguageListResponse(
        languages: json.readObjectList('languages').map(Language.fromJson).toList(),
      );

  final List<Language> languages;

  Map<String, Object?> toJson() => {
        'languages': [for (final language in languages) language.toJson()],
      };
}

/// Response body of `GET /translations?language=<code>`: every
/// `tblTranslation` row of one language, as `translationUIName → translationUIText`.
class TranslationBundle {
  const TranslationBundle({required this.languageCode, required this.texts});

  factory TranslationBundle.fromJson(Map<String, Object?> json) {
    final raw = json.readObject('translations');
    return TranslationBundle(
      languageCode: json.readString('language'),
      texts: {
        for (final MapEntry(:key, :value) in raw.entries)
          key: value is String
              ? value
              : throw FormatException('Translation "$key" must be a string, got ${value.runtimeType}.'),
      },
    );
  }

  final String languageCode;
  final Map<String, String> texts;

  Map<String, Object?> toJson() => {'language': languageCode, 'translations': texts};
}

/// Response body of `GET /me/language`. [languageCode] is `null` when the
/// user has no language in `tblUserLanguage`.
class UserLanguageResponse {
  const UserLanguageResponse({required this.languageCode});

  factory UserLanguageResponse.fromJson(Map<String, Object?> json) {
    final code = json['languageCode'];
    if (code != null && code is! String) {
      throw FormatException('Expected "languageCode" to be a string or null, got ${code.runtimeType}.');
    }
    return UserLanguageResponse(languageCode: code as String?);
  }

  final String? languageCode;

  Map<String, Object?> toJson() => {'languageCode': languageCode};
}
