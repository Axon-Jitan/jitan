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

  // Web sidebar
  static const sidebarBackground = ink;
  static const sidebarItemActive = Color(0xFF25302E);
  static const sidebarText = Color(0xFFC5CCCA);
  static const sidebarTextActive = surface;
  static const sidebarCaption = Color(0xFFA7B0AD);

  // Status
  /// "Active" status text.
  static const success = Color(0xFF16856B);
}
