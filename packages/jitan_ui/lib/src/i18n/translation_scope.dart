import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';

/// Makes the loaded [Translations] available to every widget below it.
///
/// Place it above `MaterialApp` so every route can read it. Replacing
/// [translations] (e.g. after a language change) rebuilds every widget that
/// reads text.
class TranslationScope extends InheritedWidget {
  const TranslationScope({super.key, required this.translations, required super.child});

  final Translations translations;

  static Translations of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TranslationScope>();
    assert(scope != null, 'No TranslationScope above this widget.');
    return scope!.translations;
  }

  @override
  bool updateShouldNotify(TranslationScope oldWidget) => !identical(translations, oldWidget.translations);
}

/// `context.t('company.add')`: the only way widgets obtain UI text.
extension TranslationLookup on BuildContext {
  String t(String key, {Map<String, Object> args = const {}}) =>
      TranslationScope.of(this).t(key, args: args);

  String tPlural(String key, int count) => TranslationScope.of(this).plural(key, count);

  /// [Translations.tOrNull]: `null` when no text exists for [key].
  String? tOrNull(String key) => TranslationScope.of(this).tOrNull(key);
}
