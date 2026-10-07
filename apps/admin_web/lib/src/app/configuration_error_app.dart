import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_text_keys.dart';

/// Shown instead of the app when the build is missing required
/// configuration, so a bad deployment fails visibly (ENGINEERING_RULES §20).
///
/// Without an API address no database language can load, so this screen is
/// in built-in English.
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) => TranslationScope(
        translations: Translations.english(),
        child: MaterialApp(
          theme: JitanTheme.light(),
          debugShowCheckedModeBanner: false,
          home: Builder(
            builder: (context) => Scaffold(
              body: JitanErrorState(
                title: context.t(AdminTextKeys.configErrorTitle),
                message: context.t(AdminTextKeys.configErrorMessage),
              ),
            ),
          ),
        ),
      );
}
