import 'package:flutter/painting.dart';

import 'jitan_colors.dart';
import 'jitan_text_styles.dart';

/// Text styles of the mobile screens (Figma `01 — Employee App`, 390 × 844
/// frames). Web screens use [JitanTextStyles].
abstract final class JitanMobileTextStyles {
  static const _base = TextStyle(
    fontFamily: JitanTextStyles.fontFamily,
    package: JitanTextStyles.fontPackage,
    color: JitanColors.ink,
    height: 1.21,
  );

  static const _regular = FontWeight.w400;
  static const _semiBold = FontWeight.w600;
  static const _bold = FontWeight.w700;

  /// "jitan." at the top of onboarding screens.
  static final logo = _base.copyWith(fontSize: 22, fontWeight: _bold, color: JitanColors.vermilion);

  /// Small uppercase line above a hero title ("YOUR WORKDAY, SIMPLIFIED").
  static final eyebrow = _base.copyWith(
    fontSize: 10,
    fontWeight: _bold,
    color: JitanColors.vermilion,
    letterSpacing: 0.7,
  );

  /// Hero titles (Welcome, Join your workplace).
  static final display = _base.copyWith(fontSize: 31, fontWeight: _semiBold, height: 1.12);

  /// Large "You're ready." title.
  static final displayLarge = _base.copyWith(fontSize: 34, fontWeight: _semiBold);

  /// Screen titles ("Is this you?", "Finish your setup.").
  static final title = _base.copyWith(fontSize: 30, fontWeight: _semiBold);

  /// Form screen title ("Set your password").
  static final formTitle = _base.copyWith(fontSize: 26, fontWeight: _semiBold);

  /// Error screen title ("QR not recognised").
  static final errorTitle = _base.copyWith(fontSize: 25, fontWeight: _semiBold);

  /// Lead paragraph under a hero title.
  static final body = _base.copyWith(fontSize: 14, fontWeight: _regular, color: JitanColors.inkMuted, height: 1.45);

  /// Lead paragraph, larger (Permissions, Ready).
  static final bodyLarge = _base.copyWith(fontSize: 15, fontWeight: _regular, color: JitanColors.inkMuted, height: 1.4);

  /// Small muted paragraph (form and error subtitles, card descriptions).
  static final caption = _base.copyWith(fontSize: 12, fontWeight: _regular, color: JitanColors.inkMuted);

  static final cardTitle = _base.copyWith(fontSize: 16, fontWeight: _semiBold);
  static final cardTitleSmall = _base.copyWith(fontSize: 15, fontWeight: _semiBold);
  static final cardText = _base.copyWith(fontSize: 12, fontWeight: _regular, color: JitanColors.inkMuted);

  /// Name on the identity card.
  static final identityName = _base.copyWith(fontSize: 20, fontWeight: _semiBold);
  static final identityDetail = _base.copyWith(fontSize: 13, fontWeight: _regular, color: JitanColors.inkMuted);

  /// Notes (security note, error help): title and text.
  static final noteTitle = _base.copyWith(fontSize: 11, fontWeight: _semiBold);
  static final noteText = _base.copyWith(fontSize: 10, fontWeight: _regular, color: JitanColors.inkMuted);

  /// Privacy note on the Permissions screen (slightly larger).
  static final noteTitleLarge = _base.copyWith(fontSize: 13, fontWeight: _semiBold);

  /// Form fields.
  static final fieldLabel = _base.copyWith(fontSize: 10, fontWeight: _bold, color: JitanColors.inkMuted);
  static final fieldText = _base.copyWith(fontSize: 12, fontWeight: _regular);
  static final fieldHint = _base.copyWith(fontSize: 12, fontWeight: _regular, color: JitanColors.inkMuted);
  static final fieldError = _base.copyWith(fontSize: 10, fontWeight: _semiBold, color: JitanColors.errorStrong);

  /// Text links under the main button ("Not you? Go back").
  static final link = _base.copyWith(fontSize: 13, fontWeight: _semiBold, color: JitanColors.inkMuted);

  /// Step counter ("7 of 8").
  static final step = _base.copyWith(fontSize: 10, fontWeight: _semiBold, color: JitanColors.inkMuted);

  /// Rows of the setup summary on the Ready screen.
  static final summary = _base.copyWith(fontSize: 13, fontWeight: _regular);

  /// "SETUP COMPLETE" badge.
  static final badge = _base.copyWith(fontSize: 10, fontWeight: _bold, color: JitanColors.success);
}
