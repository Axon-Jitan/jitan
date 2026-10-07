import 'package:flutter/material.dart';

import 'jitan_colors.dart';
import 'jitan_text_styles.dart';

/// The Material theme every Jitan app starts from.
abstract final class JitanTheme {
  static ThemeData light() => ThemeData(
        useMaterial3: true,
        fontFamily: 'packages/${JitanTextStyles.fontPackage}/${JitanTextStyles.fontFamily}',
        scaffoldBackgroundColor: JitanColors.warmWhite,
        colorScheme: ColorScheme.fromSeed(
          seedColor: JitanColors.vermilion,
          primary: JitanColors.vermilion,
          onPrimary: JitanColors.surface,
          surface: JitanColors.surface,
          onSurface: JitanColors.ink,
          error: JitanColors.vermilion,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: JitanColors.vermilion),
      );
}
