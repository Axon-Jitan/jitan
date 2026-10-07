import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/admin_strings.dart';

/// Shown instead of the app when the build is missing required
/// configuration, so a bad deployment fails visibly (ENGINEERING_RULES §20).
class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AdminStrings.appTitle,
        theme: JitanTheme.light(),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: JitanErrorState(
            title: AdminStrings.configErrorTitle,
            message: AdminStrings.configErrorMessage,
          ),
        ),
      );
}
