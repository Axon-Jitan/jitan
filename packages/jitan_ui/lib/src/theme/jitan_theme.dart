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

  /// [light] for the web apps, without a click effect: pressing a button,
  /// field, menu item or row shows no ripple and no pressed tint (product
  /// decision 2026-10-20). Buttons keep their hover tint and the keyboard
  /// focus outline stays; hover effects a component designs (table rows,
  /// the sidebar, menu rows) set their own colour. Flutter's default grey
  /// hover is off, so input fields, checkbox rows and list rows don't turn
  /// grey under the mouse. The mobile apps keep the touch ripple, the
  /// expected feedback on a phone.
  static ThemeData web() => light().copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        filledButtonTheme: const FilledButtonThemeData(style: _noPressEffect),
        textButtonTheme: const TextButtonThemeData(style: _noPressEffect),
        outlinedButtonTheme: const OutlinedButtonThemeData(style: _noPressEffect),
        elevatedButtonTheme: const ElevatedButtonThemeData(style: _noPressEffect),
        iconButtonTheme: const IconButtonThemeData(style: _noPressEffect),
        menuButtonTheme: const MenuButtonThemeData(style: _noPressEffect),
        checkboxTheme: const CheckboxThemeData(overlayColor: _noPressOverlay),
        radioTheme: const RadioThemeData(overlayColor: _noPressOverlay),
        switchTheme: const SwitchThemeData(overlayColor: _noPressOverlay),
        // Thin and quiet: shown while scrolling or under the pointer.
        scrollbarTheme: ScrollbarThemeData(
          thickness: const WidgetStatePropertyAll(6),
          radius: const Radius.circular(8),
          crossAxisMargin: 3,
          mainAxisMargin: 4,
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => JitanColors.ink.withValues(
              alpha: states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered) ? 0.4 : 0.22,
            ),
          ),
        ),
      );

  static const _noPressEffect = ButtonStyle(
    splashFactory: NoSplash.splashFactory,
    overlayColor: _noPressOverlay,
  );

  /// Transparent while pressed; the usual hover and focus tints otherwise.
  static const _noPressOverlay = _PressedTransparent();
}

class _PressedTransparent implements WidgetStateProperty<Color?> {
  const _PressedTransparent();

  @override
  Color? resolve(Set<WidgetState> states) =>
      states.contains(WidgetState.pressed) ? Colors.transparent : null;
}
