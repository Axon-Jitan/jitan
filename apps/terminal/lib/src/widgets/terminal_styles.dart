import 'package:flutter/painting.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The tablet's type: read from arm's length, so larger than the other apps.
abstract final class TerminalStyles {
  static const _base = TextStyle(
    fontFamily: JitanTextStyles.fontFamily,
    package: JitanTextStyles.fontPackage,
    color: JitanColors.ink,
  );

  static final clock = _base.copyWith(fontSize: 84, fontWeight: FontWeight.w600, height: 1.2);
  static final date = _base.copyWith(fontSize: 18, color: JitanColors.inkMuted);
  static final title = _base.copyWith(fontSize: 36, fontWeight: FontWeight.w600);
  static final prompt = _base.copyWith(fontSize: 26, fontWeight: FontWeight.w600, height: 1.2);
  static final body = _base.copyWith(fontSize: 18, color: JitanColors.inkMuted, height: 1.25);
  static final hint = _base.copyWith(fontSize: 16, color: JitanColors.inkMuted, height: 1.25);
  static final small = _base.copyWith(fontSize: 13, color: JitanColors.inkMuted);
  static final quiet = _base.copyWith(fontSize: 13, color: JitanColors.inkMuted);
  static final rowTitle = _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
  static final rowDetail = _base.copyWith(fontSize: 14, color: JitanColors.inkMuted);
  static final button = _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);
}
