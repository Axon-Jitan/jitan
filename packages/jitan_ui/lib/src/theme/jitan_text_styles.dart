import 'package:flutter/painting.dart';

import 'jitan_colors.dart';

/// Text styles from Figma. Font: Inter (bundled in this package).
abstract final class JitanTextStyles {
  /// Font family reference for a font bundled in this package.
  static const fontFamily = 'Inter';
  static const fontPackage = 'jitan_ui';

  static const _base = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    color: JitanColors.ink,
    height: 1.2,
  );

  static const _regular = FontWeight.w400;
  static const _semiBold = FontWeight.w600;
  static const _bold = FontWeight.w700;

  // Page
  static final pageTitle = _base.copyWith(fontSize: 30, fontWeight: _semiBold);
  static final pageSubtitle =
      _base.copyWith(fontSize: 13, fontWeight: _regular, color: JitanColors.inkMuted);

  // Tables
  static final tableHeader =
      _base.copyWith(fontSize: 10, fontWeight: _bold, color: JitanColors.inkMuted);
  static final tableCell = _base.copyWith(fontSize: 11, fontWeight: _regular);
  static final tableCellStrong = _base.copyWith(fontSize: 11, fontWeight: _semiBold);

  // Inputs and buttons
  static final inputText = _base.copyWith(fontSize: 11, fontWeight: _regular);
  static final inputHint =
      _base.copyWith(fontSize: 11, fontWeight: _regular, color: JitanColors.inkMuted);
  static final buttonLabel =
      _base.copyWith(fontSize: 11, fontWeight: _semiBold, color: JitanColors.surface);

  // Web sidebar
  static final logo = _base.copyWith(fontSize: 26, fontWeight: _bold, color: JitanColors.vermilion);
  static final sidebarCaption =
      _base.copyWith(fontSize: 10, fontWeight: _bold, color: JitanColors.sidebarCaption);
  static final navItem =
      _base.copyWith(fontSize: 12, fontWeight: _regular, color: JitanColors.sidebarText);
  static final navItemActive =
      _base.copyWith(fontSize: 12, fontWeight: _semiBold, color: JitanColors.sidebarTextActive);

  // State views (loading / empty / error)
  static final stateTitle = _base.copyWith(fontSize: 13, fontWeight: _semiBold);
  static final stateMessage =
      _base.copyWith(fontSize: 11, fontWeight: _regular, color: JitanColors.inkMuted);
}
