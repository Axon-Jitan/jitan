import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

import '../l10n/employee_text_keys.dart';
import 'phone_widgets.dart';

/// The layout of the first-run screens: onboarding (Figma `1591:356`) and
/// sign-in and recovery (`1592:211`), 2026-11-13. The wordmark or a back
/// chevron with "n of 5" at the top, a title and a line under it, the
/// content, then the main button and a quiet link at the bottom. The same
/// calm style as Home.
class PhoneStepPage extends StatelessWidget {
  const PhoneStepPage({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBack = false,
    this.step,
    this.large = false,
    this.contentGap = 24,
    this.above,
    this.children = const [],
    this.note,
    this.action,
    this.link,
    this.bottomBar,
  });

  /// Onboarding's steps after the scan: "Is this you?" … "Set a password".
  static const stepCount = 5;

  final String title;
  final String? subtitle;

  /// Shows the back chevron instead of the wordmark; `null` while busy.
  final VoidCallback? onBack;
  final bool showBack;

  /// "2 of 5" at the top right.
  final int? step;

  /// The bigger title of Welcome and Ready.
  final bool large;

  /// Between the subtitle and the content.
  final double contentGap;

  /// Above the title: "Setup QR verified", or an error's icon.
  final Widget? above;
  final List<Widget> children;

  /// Above the main button: something wasn't saved.
  final Widget? note;
  final Widget? action;
  final Widget? link;

  /// The tab bar, on pages opened from a tab (Profile's pages).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          if (showBack)
                            IconButton(
                              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                              onPressed: onBack,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                              icon: const PhoneBackIcon(),
                            )
                          else
                            const JitanWordmark(),
                          const Spacer(),
                          if (step case final n?)
                            Text(
                              context.t(EmployeeTextKeys.step, args: {'n': n, 'total': stepCount}),
                              style: JitanMobileTextStyles.label,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (above case final above?) ...[above, const SizedBox(height: 10)],
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: large
                            ? JitanMobileTextStyles.pageTitle.copyWith(fontSize: 34, letterSpacing: -1, height: 40 / 34)
                            : JitanMobileTextStyles.pageTitle,
                      ),
                    ),
                    if (subtitle case final subtitle?) ...[
                      SizedBox(height: large ? 10 : 6),
                      Text(subtitle, style: JitanMobileTextStyles.pageSubtitle),
                    ],
                    SizedBox(height: contentGap),
                    ...children,
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (note case final note?) ...[note, const SizedBox(height: 12)],
            ?action,
            if (link case final link?) ...[if (action != null) const SizedBox(height: 4), Center(child: link)],
            if (bottomBar case final bar?) ...[const SizedBox(height: 12), bar],
          ],
        ),
      ),
    ),
  );
}

/// The round icon above an error's title: red for a dead end, amber for
/// "do this instead", grey for "try again".
class PhoneStatusIcon extends StatelessWidget {
  const PhoneStatusIcon({super.key, required this.tone});

  final PhoneTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, color, icon) = switch (tone) {
      PhoneTone.error => (JitanColors.errorSurface, JitanColors.error, Icons.priority_high_rounded),
      PhoneTone.warning => (JitanColors.warningSurface, JitanColors.warning, Icons.priority_high_rounded),
      PhoneTone.retry => (JitanColors.inputFill, JitanColors.ink, Icons.refresh_rounded),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}

enum PhoneTone { error, warning, retry }
