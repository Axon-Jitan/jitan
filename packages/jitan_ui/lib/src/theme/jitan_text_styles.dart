import 'package:flutter/painting.dart';

import 'jitan_colors.dart';

/// Text styles from Figma. Fonts (bundled in this package): Inter for text,
/// Inter Display for titles, with slightly tighter spacing at large sizes.
abstract final class JitanTextStyles {
  /// Font family reference for a font bundled in this package.
  static const fontFamily = 'Inter';
  static const fontPackage = 'jitan_ui';

  /// Inter drawn for large sizes: page and dialog titles, the logo.
  static const displayFontFamily = 'InterDisplay';

  static const _base = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    color: JitanColors.ink,
    height: 1.2,
  );

  static const _display = TextStyle(
    fontFamily: displayFontFamily,
    package: fontPackage,
    color: JitanColors.ink,
    height: 1.15,
  );

  static const _regular = FontWeight.w400;
  static const _medium = FontWeight.w500;
  static const _semiBold = FontWeight.w600;
  static const _bold = FontWeight.w700;

  // Page
  static final pageTitle = _display.copyWith(fontSize: 32, fontWeight: _semiBold, letterSpacing: -0.6);
  static final pageSubtitle =
      _base.copyWith(fontSize: 15, fontWeight: _regular, color: JitanColors.inkMuted);

  // Tables
  static final tableHeader =
      _base.copyWith(fontSize: 13, fontWeight: _semiBold, color: JitanColors.inkMuted);
  static final tableCell = _base.copyWith(fontSize: 14, fontWeight: _regular);
  static final tableCellStrong = _base.copyWith(fontSize: 14, fontWeight: _semiBold);

  // Modals and forms
  static final modalTitle = _display.copyWith(fontSize: 26, fontWeight: _semiBold, letterSpacing: -0.4);
  static final modalSubtitle =
      _base.copyWith(fontSize: 15, fontWeight: _regular, color: JitanColors.inkMuted);
  static final fieldLabel =
      _base.copyWith(fontSize: 13, fontWeight: _medium, color: JitanColors.inkMuted);
  static final fieldError =
      _base.copyWith(fontSize: 13, fontWeight: _regular, color: JitanColors.error);

  // Inputs and buttons
  static final inputText = _base.copyWith(fontSize: 15, fontWeight: _regular);
  static final inputHint =
      _base.copyWith(fontSize: 15, fontWeight: _regular, color: JitanColors.inkMuted);
  static final buttonLabel =
      _base.copyWith(fontSize: 14, fontWeight: _semiBold, color: JitanColors.surface);

  // Web sidebar
  static final logo = _display.copyWith(fontSize: 26, fontWeight: _bold, color: JitanColors.vermilion, letterSpacing: -0.5);
  static final sidebarCaption =
      _base.copyWith(fontSize: 12, fontWeight: _bold, color: JitanColors.sidebarCaption);
  static final navItem =
      _base.copyWith(fontSize: 15, fontWeight: _regular, color: JitanColors.sidebarText);
  static final navItemActive =
      _base.copyWith(fontSize: 15, fontWeight: _semiBold, color: JitanColors.sidebarTextActive);

  // State views (loading / empty / error)
  static final stateTitle = _base.copyWith(fontSize: 16, fontWeight: _semiBold, letterSpacing: -0.1);
  static final stateMessage =
      _base.copyWith(fontSize: 15, fontWeight: _regular, color: JitanColors.inkMuted);
}
