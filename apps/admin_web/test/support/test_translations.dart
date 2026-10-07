import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// Test fixture. Only the relative-date texts are filled in (their `{n}`
/// matters to the assertions); every other lookup shows its key, exactly as
/// production does for a missing key. Widget tests therefore assert which
/// key a widget uses, without duplicating real copy.
final testTranslations = Translations(
  languageCode: 'en',
  selected: const {},
  fallback: const {
    'common.date.today': 'Today',
    'common.date.yesterday': 'Yesterday',
    'common.date.daysAgo.one': '{n} day ago',
    'common.date.daysAgo.other': '{n} days ago',
    'common.date.weeksAgo.one': '{n} week ago',
    'common.date.weeksAgo.other': '{n} weeks ago',
    'common.date.monthsAgo.one': '{n} month ago',
    'common.date.monthsAgo.other': '{n} months ago',
    'common.date.yearsAgo.one': '{n} year ago',
    'common.date.yearsAgo.other': '{n} years ago',
  },
);

Widget withTestTranslations(Widget child) => TranslationScope(translations: testTranslations, child: child);
