import 'package:flutter/painting.dart';

/// Colour tokens from Figma.
///
/// Brand colours are defined on `00 — Foundations`; the rest are taken from
/// the approved screens (`03 — HR`, `04 — Admin`). Use these names, never
/// raw hex values, in app code.
abstract final class JitanColors {
  // Brand (00 — Foundations)
  /// Primary brand / action.
  static const vermilion = Color(0xFFE94B35);

  /// Typography / dark surfaces.
  static const ink = Color(0xFF18201F);

  /// Primary background.
  static const warmWhite = Color(0xFFFAF9F6);

  // Neutrals (screens)
  static const surface = Color(0xFFFFFFFF);

  /// Secondary text, table headers, placeholder text.
  static const inkMuted = Color(0xFF687370);

  /// Input fill (search field).
  static const inputFill = Color(0xFFF2F0EB);

  /// Outline of form fields and secondary buttons.
  static const inputBorder = Color(0xFFE7E5E0);

  /// Validation and form error text.
  static const error = vermilion;

  // Web sidebar
  static const sidebarBackground = ink;
  static const sidebarItemActive = Color(0xFF25302E);
  static const sidebarText = Color(0xFFC5CCCA);
  static const sidebarTextActive = surface;
  static const sidebarCaption = Color(0xFFA7B0AD);

  // Status
  /// "Active" status text.
  static const success = Color(0xFF16856B);

  // Tables (table design specification, 2026-10-20)
  /// Header row background, edge to edge.
  static const tableHeader = Color(0xFFF7F6F3);

  /// Background of rows 2, 4, … (very subtle).
  static const tableStripe = Color(0xFFF8F7F5);

  /// Hover on a clickable row.
  static const tableHover = Color(0xFFF2F0EB);

  /// Pending status that needs attention ("Not activated" in Figma).
  static const warning = Color(0xFFB56B16);

  /// Background of success pills ("READY TO SCAN").
  static const successSurface = Color(0xFFE8F5F1);

  // Mobile (01 — Employee App)
  /// Strong error text and icons on error screens.
  static const errorStrong = Color(0xFFB33A2E);

  /// Background of error notes and icons.
  static const errorSurface = Color(0xFFFBE8E4);

  /// Background of warning notes and icons (pairs with [warning]).
  static const warningSurface = Color(0xFFFFF1DC);

  /// Informational / retry state text and icons.
  static const info = Color(0xFF3B6FD8);
  static const infoSurface = Color(0xFFEAF0FC);

  /// Light Vermilion tint, e.g. the note under the registration choices.
  static const brandTint = Color(0xFFFCE5E1);

  /// Warm note background (privacy note).
  static const noteSurface = Color(0xFFF2EEE9);

  /// Outline of unselected choice cards.
  static const cardBorder = Color(0xFFE5E6E1);

  /// Outline of an unselected radio indicator.
  static const radioBorder = Color(0xFFB9C0BD);

  /// Unselected language dot (Onboarding / 06B Language).
  static const radioIdle = Color(0xFFD6DAD7);

  /// Disabled web button: fill and label (Reset account access, not
  /// activated).
  static const disabledFill = Color(0xFFE8E7E3);
  static const disabledText = Color(0xFFA2AAA7);
}
