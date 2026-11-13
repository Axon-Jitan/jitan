import 'package:flutter/material.dart';
import 'package:jitan_ui/jitan_ui.dart';

/// The layout of every Home state (Figma `1585:2`): the logo, a title and a
/// line under it, the content (pull to refresh), then a note, the main
/// button, a quiet link and the tab bar at the bottom.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.navBar,
    required this.onRefresh,
    this.title,
    this.subtitle,
    this.notice,
    this.children = const [],
    this.note,
    this.action,
    this.link,
  });

  final Widget navBar;
  final Future<void> Function() onRefresh;
  final String? title;
  final String? subtitle;

  /// Under the subtitle: "Couldn't refresh · Try again".
  final Widget? notice;
  final List<Widget> children;

  /// Above the main button: something wasn't saved.
  final Widget? note;
  final Widget? action;
  final Widget? link;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: JitanColors.warmWhite,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                color: JitanColors.ink,
                onRefresh: onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(alignment: Alignment.centerLeft, child: JitanWordmark()),
                      const SizedBox(height: 26),
                      if (title case final title?) Semantics(header: true, child: Text(title, style: JitanMobileTextStyles.pageTitle)),
                      if (subtitle case final subtitle?) ...[
                        const SizedBox(height: 6),
                        Text(subtitle, style: JitanMobileTextStyles.pageSubtitle),
                      ],
                      if (notice case final notice?) ...[const SizedBox(height: 4), notice],
                      if (title != null || subtitle != null) const SizedBox(height: 20),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
            if (note case final note?) ...[note, const SizedBox(height: 12)],
            ?action,
            if (link case final link?) ...[if (action != null) const SizedBox(height: 4), Center(child: link)],
            const SizedBox(height: 12),
            navBar,
          ],
        ),
      ),
    ),
  );
}

/// The grey shapes shown while the day loads.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block(double height, {double? width, double radius = 8}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: JitanColors.inputFill, borderRadius: BorderRadius.circular(radius)),
    );
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(30, width: 220),
          const SizedBox(height: 10),
          block(16, width: 160),
          const SizedBox(height: 22),
          block(141, radius: 20),
          const SizedBox(height: 12),
          block(64, radius: 18),
        ],
      ),
    );
  }
}
