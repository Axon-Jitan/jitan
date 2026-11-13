import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'employee_text_keys.dart';

/// How a language is named in a list: by its own name ("Nederlands"), with
/// its name in the current language under it ("Dutch"). Onboarding's and
/// Profile's language lists, and Profile's Language row.
abstract final class LanguageNames {
  /// The language's own name; English's is built in.
  static String own(BuildContext context, Language language) =>
      language.code == englishLanguageCode ? context.t(EmployeeTextKeys.languageEnglish) : language.name;

  /// Its name in the current language, unless it reads the same ("English"
  /// under "English").
  static String? translated(BuildContext context, Language language) {
    final translated = context.tOrNull(CommonTextKeys.languageName(language.code));
    return translated == own(context, language) ? null : translated;
  }

  /// The name of the language the app is shown in, for Profile's row.
  static String current(BuildContext context) {
    final code = TranslationScope.of(context).languageCode;
    if (code == englishLanguageCode) return context.t(EmployeeTextKeys.languageEnglish);
    return context.tOrNull(CommonTextKeys.languageName(code)) ?? code.toUpperCase();
  }
}
