import 'package:flutter/widgets.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_models/jitan_models.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../common/relative_date_text.dart';

/// The words of the Companies page.
abstract final class CompanyText {
  /// "Today", "Yesterday", "3 Nov"; "—" without any change recorded.
  static String updated(BuildContext context, CompanySummary company, DateTime now) {
    final at = company.lastUpdatedAt;
    return at == null ? context.t(CommonTextKeys.valueUnavailable) : relativeDateText(TranslationScope.of(context), at, now: now);
  }

  /// "Wednesday 11 November, 09:42", the exact moment on hover.
  static String updatedExactly(BuildContext context, DateTime at) {
    final local = at.toLocal();
    return '${context.t(CommonTextKeys.weekdayLong[local.weekday - 1])} ${local.day} '
        '${context.t(CommonTextKeys.monthLong[local.month - 1])}, '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// [name] as the server compares names: without capitals or accents
  /// (CLARIFY-16), so "almeco" and "Almécó" are Almeco. Only for warning
  /// while typing; the server decides.
  static String comparable(String name) {
    const from = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    final lower = name.trim().toLowerCase();
    final out = StringBuffer();
    for (final char in lower.split('')) {
      final i = from.indexOf(char);
      out.write(i < 0 ? char : to[i]);
    }
    return out.toString();
  }
}
