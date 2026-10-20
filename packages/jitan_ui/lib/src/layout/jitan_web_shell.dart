import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import 'jitan_web_sidebar.dart';

/// Web page frame: sidebar on the left, scrollable page on the right.
///
/// The page is at most [JitanDimensions.pageMaxWidth] wide (Figma's main
/// area: 1120 px of content plus its padding) and centred in the space
/// beside the sidebar, so on a wide screen columns do not drift apart.
///
/// Below [JitanDimensions.compactLayoutBreakpoint] the sidebar moves into a
/// drawer opened from a slim top bar, so narrow windows keep a usable page.
class JitanWebShell extends StatelessWidget {
  const JitanWebShell({super.key, required this.sidebar, required this.child});

  final JitanWebSidebar sidebar;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < JitanDimensions.compactLayoutBreakpoint;
          // Exactly the window's width beside the sidebar, at most
          // pageMaxWidth: a tight width, so a wide table inside scrolls
          // instead of making the page wider than the window.
          final page = LayoutBuilder(
            builder: (context, area) => Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: math.min(area.maxWidth, JitanDimensions.pageMaxWidth),
                height: area.maxHeight,
                child: child,
              ),
            ),
          );
          if (!compact) {
            return Scaffold(body: Row(children: [sidebar, Expanded(child: page)]));
          }
          return Scaffold(
            appBar: AppBar(
              backgroundColor: JitanColors.sidebarBackground,
              foregroundColor: JitanColors.surface,
              toolbarHeight: 48,
            ),
            drawer: Drawer(
              width: JitanDimensions.sidebarWidth,
              backgroundColor: JitanColors.sidebarBackground,
              shape: const RoundedRectangleBorder(),
              child: sidebar,
            ),
            body: page,
          );
        },
      );
}
