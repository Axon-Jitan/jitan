import 'package:flutter/material.dart';

import '../theme/jitan_colors.dart';
import '../theme/jitan_dimensions.dart';
import 'jitan_web_sidebar.dart';

/// Web page frame: sidebar on the left, scrollable page on the right.
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
          if (!compact) {
            return Scaffold(body: Row(children: [sidebar, Expanded(child: child)]));
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
            body: child,
          );
        },
      );
}
