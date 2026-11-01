import 'package:flutter/material.dart';
import 'package:jitan_core/jitan_core.dart';
import 'package:jitan_ui/jitan_ui.dart';

import 'terminal_styles.dart';

/// Every screen of the tablet: the wordmark, where this is, the language, and
/// [child] in the room that's left. Only what someone at the tablet needs: an
/// online dot says nothing while everything works.
class TerminalPage extends StatelessWidget {
  const TerminalPage({
    super.key,
    required this.place,
    required this.child,
    required this.languages,
    required this.languageCode,
    required this.onLanguage,
  });

  final String place;
  final Widget child;

  /// code → name; a language menu shows only when there is a choice.
  final Map<String, String> languages;
  final String languageCode;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 28, 40, 0),
            child: Row(
              children: [
                JitanWordmark(style: JitanMobileTextStyles.logo.copyWith(fontSize: 26)),
                const Spacer(),
                Text(place, style: TerminalStyles.small),
                const SizedBox(width: 18),
                _language(context),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );

  Widget _language(BuildContext context) {
    final current = context.t(CommonTextKeys.languageName(languageCode));
    final label = Text(current, style: TerminalStyles.small.copyWith(color: JitanColors.ink, fontWeight: FontWeight.w500));
    if (languages.length < 2) return label;
    return PopupMenuButton<String>(
      onSelected: onLanguage,
      color: JitanColors.surface,
      tooltip: current,
      itemBuilder: (_) => [
        for (final MapEntry(key: code, value: name) in languages.entries) PopupMenuItem(value: code, child: Text(name)),
      ],
      child: label,
    );
  }
}
